# Ambry design tour — how to re-run it

Everything in this directory is untracked scratch outside the repo. No tracked
file in `/Users/orchestrator/code/pantry` was modified; the tour reuses the
repo's own `.maestro/acceptance/_login.yaml` by absolute path.

## One command, after a rebuild

```sh
~/agents/runs/2026-09-12-design-tour/build.sh   # bake the branch Data API URL, install, launch
~/agents/runs/2026-09-12-design-tour/tour.sh    # fixture + light + dark + ax5 + thumbs + restore
~/agents/runs/2026-09-12-design-tour/make-index.sh
~/agents/runs/2026-09-12-design-tour/scratch/prune-out.sh   # REQUIRED after every tour
```

`prune-out.sh` is not just housekeeping. Maestro writes the values passed with
`-e` into each flow's `commands.json` and `logs/maestro.log`, so **a finished run
leaves `TEST_PASSWORD` in plain text under `out/`** — those two file types are
what the script deletes (along with ~500 MB of hierarchy dumps). Verify with:

```sh
source ./env.sh && grep -rlF "$TEST_PASSWORD" . || echo clean
```

`tour.sh` on its own is the repeatable step: it sets the simulator appearance and
text size per mode, relaunches the app, runs `flows/` with `maestro --device
<udid> test`, writes `shots/<mode>/<name>.png`, makes the 480px JPEG copies under
`thumbs/<mode>/`, and restores the simulator to light / `large` when it is done.

Narrower runs:

```sh
tour.sh dark                 # one mode
SKIP_SEED=1 tour.sh light    # skip the fixture flow
./fill.sh "10-pantry 40-recipes" "light dark ax5"   # re-capture just those flows
```

`fill.sh` is the targeted second pass: same appearance table, same collection,
same restore — for when one flow's selector was wrong, or a fixture landed after
a mode had already run, and re-running the whole tour to fix six screenshots
would be waste.

`build.sh` prints the proof line that must be read before any flow runs:

```
PROOF  prod id hits: 0  branch id hits: 1   (prod MUST be 0)
```

`prod id hits` is a `strings Ambry.app/main.jsbundle | grep -c <production
endpoint id>` — the bundle is Hermes bytecode, so a plain `grep` on the file
reports 0 for everything and proves nothing. A non-zero left-hand number means
the build is pointed at production and the tour must not be run.

## Modes

| mode | `xcrun simctl ui <udid> …` |
|---|---|
| `light` | `appearance light` + `content_size large` |
| `dark` | `appearance dark` + `content_size large` |
| `ax5` | `appearance light` + `content_size accessibility-extra-extra-extra-large` (the largest token `simctl ui --help` lists) |

## Credentials

`env.sh` sources `~/agents/.env.acceptance` **internally** and exports only
`TEST_EMAIL` / `TEST_PASSWORD`, which reach maestro through `-e` — the same
pattern as `~/agents/scripts/acceptance-cycle.sh`. Nothing in this directory
contains a credential value, and no script prints one.

## The branch

| | |
|---|---|
| branch | `design-tour-2026-09-12` — `br-winter-hall-a630bzfe` |
| endpoint | `ep-lucky-heart-a6fj97ku` (region `us-west-2`) |
| Data API | `https://ep-lucky-heart-a6fj97ku.apirest.us-west-2.aws.neon.tech/neondb/rest/v1` |
| direct host | `ep-lucky-heart-a6fj97ku.us-west-2.aws.neon.tech` (what `ACCEPTANCE_TARGET_HOST` is derived from) |

The branch's Data API needed **no enabling step**: `neonctl api
/projects/red-water-68835077/branches/br-winter-hall-a630bzfe/data-api/neondb`
answered `"status": "active"` with the same settings as production's, confirming
the 2026-09-03 finding that a child branch inherits production's Data API and its
auth providers. (`neonctl api list` does expose `POST …/branches/{id}/data-api/{db}`
if a future branch ever comes up without one.) Verified end to end before
building, with `~/agents/scripts/neon-branch-keepalive.mjs`: sign-in as the
seeded account, then `200 … (1 row)` on an authenticated read.

Delete the branch after the review:

```sh
neonctl branches delete br-winter-hall-a630bzfe --project-id red-water-68835077
```

## Flows

| file | screens |
|---|---|
| `flows/_login.yaml` | shim → the repo's `_login.yaml` (absolute path) |
| `flows/00-seed-tour.yaml` | fixture part 1: expiring items marked used, two Fridge zones, a `Weeknight` folder with a recipe filed in it, grocery rows with one bought. Guarded, so a second run is a no-op. Run once by `tour.sh`, not per mode. |
| `flows/01-seed-outcomes.yaml` | fixture part 2: deletes the `out` rows so the `food_outcomes` ledger reaches the scorecard's floor and the Pantry tab draws the card that opens `/insights`. Also guarded. |
| `flows/10-pantry.yaml` | `pantry-index`, `pantry-search`, `expiring`, `insights`, `location-fridge`, `location-zones`, `item` |
| `flows/20-lists.yaml` | `lists`, `grocery-restock` |
| `flows/30-add.yaml` | `add`, `add-search`, `add-scan`, `add-receipt`, `capture-review` |
| `flows/40-recipes.yaml` | `recipes-cook`, `recipes-mine`, `recipes-community`, `recipe-detail`, `recipe-cook-mode`, `recipe-edit`, `recipe-new`, `recipe-import`, `recipe-folders`, `recipe-folder`, `creator-profile` |
| `flows/50-profile.yaml` | `profile`, `profile-display-name`, `profile-about-you`, `profile-household`, `add-household`, `profile-invite`, `profile-learned`, `profile-members`, `profile-reminders`, `profile-plan`, `delete-account`, `delete-account-confirm` |
| `flows/90-signed-out.yaml` | `welcome`, `sign-in`, `forgot-password`, `sign-up` — **last**, because it `launchApp: clearState: true` |

What the tour deliberately does not do: it never confirms the delete-account
dialog, never regenerates the invite code, never commits a restock, never creates
an account, and never sends a password-reset email.

## Missing — for the orchestrator to capture by deep link

The app's URL scheme is `pantry` (`app.json`). `xcrun simctl openurl` hands the
URL straight to the installed app, so it does **not** raise the SpringBoard
"Open in Ambry?" confirmation that a Maestro `openLink` (which goes through
Safari) does — that dialog is the reason the repo's `_launch.yaml` is a bare
`launchApp`. `./deeplinks.sh [modes…]` drives the three that need no token;
**check each captured PNG**, because a route that bounces still screenshots
whatever it bounced to.

| screen | route file | why the tour cannot reach it |
|---|---|---|
| first-run guide | `src/app/first-run.tsx` | Reached only from onboarding success ("Reached only from onboarding success, so no seen-flag is needed" — its own header). Nothing in a signed-in session pushes it. `pantry://first-run` |
| onboarding | `src/app/(auth)/onboarding.tsx` | The `(auth)` layout redirects any signed-in user **with a household** to the tabs, and the tour's account has one. Reaching it honestly means creating an account. `pantry://onboarding` |
| paywall | `src/app/paywall.tsx` | The Profile row is gated on `billingEnabled = !!EXPO_PUBLIC_REVENUECAT_IOS_KEY && ios` (`src/features/billing/purchases.ts:36`) and this build has no key, so no row renders — Profile shows the "Ambry Plus … Coming soon" footnote instead. The only other entry is ReceiptCapture's quota-exhausted "About Ambry Plus", which needs the monthly AI-scan quota spent. `pantry://paywall` |
| reset-password | `src/app/(auth)/reset-password.tsx` | Needs a recovery link. The screen validates nothing itself (the token's fate is decided at redemption), so `pantry://reset-password?token=<anything>` should render it — but the tour will not send a real reset email, so it is left to you. |
| join/[token] | `src/app/join/[token].tsx` | Needs an invite token. The screen deliberately sits outside both `(auth)` and `(tabs)` so it survives every session state, so `pantry://join/<token>` should render — mint a real token from Profile → Share invite link for the valid-token state, or pass a junk one for the error state. |
| creator profile, as a stranger sees it | `src/app/profile/[id]/index.tsx` | Captured as `creator-profile`, but from **your own** page: the Follow control and the "Report profile" flag are `!isMe` only (`:107`), and the recipe byline link is `!isOwner` only (`src/app/recipe/[id]/index.tsx:358`). Every public recipe on this branch belongs to the signed-in seeded account, so neither renders. Needs a second account. |
| capture-review | `src/app/capture-review.tsx` | Needs at least one row staged in the basket, and a simulator has no camera. The tour tries the scanner's typed-barcode fallback (a live Open Food Facts lookup through the Worker); when that answers "not found" or is rate-limited, the shot is simply absent. |

## Data the tour depends on

The branch is forked from production, so it arrives with real content: 21 items
in the seeded "Test Home" household across Pantry / Fridge / Freezer, 5 recipes
(2 public), 2 profiles. `flows/00-seed-tour.yaml` adds only what the branch lacks
and each block is guarded, so re-running it is a no-op:

- **waste outcomes** — `scorecard()` returns null (and the Pantry tab draws no
  card, so `/insights` is unreachable through the UI) until the household has
  `SCORECARD_FLOOR` = 5 used+expired outcomes in the current month
  (`src/features/insights/outcomes.ts:44,124`). This takes **two** steps, which
  cost a pass to find out: `00-seed-tour.yaml`'s swipe-right → "Used" gestures on
  the Expiring screen only set `status: 'out'` (`src/app/expiring.tsx:168` patches
  the status and nothing else), and the ledger is written by the DELETE paths —
  and then only when the undo window CLOSES, because migration 0040 grants no
  delete on `food_outcomes` and a row written on success could not be taken back
  by Undo. `01-seed-outcomes.yaml` does the second half: it deletes those `out`
  rows through the location screen's row trash and waits each toast out.
- **a bought grocery row** — the "Restock N bought items" affordance, and so the
  restock screen, needs one. The seeding suite empties the list on its way
  through (flows 09 and 11 both include `_empty-grocery-list.yaml`), so the
  fixture puts rows back and checks one off.
- **zones** — the suite's `15-zones` adds one and deletes it again, so the Fridge
  ends with none; the fixture adds "Top shelf" and "Door".
- **a recipe folder with a recipe in it** — `48-folders` deletes the folder it
  creates; the fixture makes "Weeknight" and files Shakshuka into it.

## Findings the tour turned up (for the HIG review, not bugs it caused)

1. **The sign-in screen's submit is below the fold at the largest accessibility
   text size.** At `accessibility-extra-extra-extra-large` on the iPhone 17 Pro,
   "Sign in" fills a third of the screen, the Google button's own label clips
   mid-word ("Continue with…" runs off the right edge), and `sign-in-submit` sits
   below the visible area. It IS reachable — `src/app/(auth)/sign-in.tsx:111` is a
   ScrollView inside the KeyboardAvoidingView — but nothing on screen says so, and
   the repo's `.maestro/acceptance/_login.yaml` taps the button without scrolling
   on the standing assumption that "the submit button stays above the keyboard".
   That assumption is what the ax5 pass broke. Evidence:
   `out/ax5/*/10-pantry/screenshots/step-019-assertCondition-Search_your_whole_pantry.png`.
2. **The Lists tab's add-field suggestions are indistinguishable from pantry
   search hits by name alone.** Typing "to" on the Lists tab offers Tofu,
   Tomatoes, Tomatillos…; typing it on the Pantry tab returns the same foods
   grouped under location headers. That is fine for a person, who can see which
   screen they are on — it is recorded here because it made a Maestro assertion
   pass on the wrong screen, and the fix (assert on a location header) is the
   same discipline a reviewer should apply.
3. **The acceptance suite assumes a household with no inventory.** Its own flow
   headers say so ("run the suite in filename order on a freshly branched Neon
   database"), but the branch that a design tour wants is one forked from
   production, with real food in it. Two flows fail on that difference — see
   `index.md` §Seeding run. Worth a note in `docs/ACCEPTANCE_TESTS.md`.

## Status of this run's captures

`shots/index.json` is the machine-readable answer; in words:

- **light** and **dark** stand at **46 of 47**. `deeplinks.sh` has since captured
  `paywall`, `first-run` and `onboarding` in all three modes — each one opened and
  verified by eye (the Ambry Plus screen in its coming-soon state, "You're all
  set", "Set up your kitchen"), so the deep-link route works and those three are
  no longer outstanding. The one screen still absent everywhere is
  `creator-profile-byline`: the byline link is `!isOwner` only and the seeded
  account owns every public recipe on this branch, so it needs a second account.
  `reset-password` and `join/<token>` still need a real token.
- **ax5** stands at **26 of 47**, and the gaps ARE the finding: see §Findings 1
  and the `index.md` table. Every ax5 failure was the same shape — a control the
  accessibility text size pushed below the fold, on a screen that had rendered
  perfectly. The flows now scroll to each one as it is found, so a re-run
  (`./fill.sh "10-pantry 20-lists 40-recipes 50-profile" ax5`) closes more of
  them each time — a second full `tour.sh` at 13:05 did exactly that; the ones still missing are listed per screen in
  `shots/index.json` under `missing_modes`. Read the ax5 set as "what the app
  does at that text size", not as a checklist to complete.
- `out/` keeps each run's `manifest.json` and the per-step screenshot Maestro
  saves at a failure — the useful half of ~600 MB of debug output, pruned to 2 MB
  by `scratch/prune-out.sh`. Re-running a flow regenerates the rest, **including
  the credential-bearing files**, so prune again after each run.
- `collect` copies into `shots/<mode>/` without clearing, so the set is a UNION
  across runs. Delete a mode's folder before a run if you want one coherent point
  in time; leave it to accumulate best-effort coverage, which is what happened
  here.
