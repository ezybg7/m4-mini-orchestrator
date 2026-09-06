import json, re
P='/Users/orchestrator/agents/artifact/summary.json'; S=json.load(open(P))
ledger=[l for l in open('/Users/orchestrator/agents/logs/merged-prs-since-2026-09-03.txt').read().splitlines() if l.strip()]
n5=sum(1 for l in ledger if l.startswith('2026-09-05')); n4=sum(1 for l in ledger if l.startswith('2026-09-04')); total=len(ledger)
S['as_of']=f'As of 2026-09-05 20:50 EDT · {n4} PRs merged Sep 4 · {n5} merged Sep 5'
S['lede']=('Everything below happened between 2026-09-04 and the evening of 2026-09-05 through the orchestrator queue: the feature-by-feature review, the fix wave, the design wave, the readiness pass, '
 'the monetization and verification specs, the skeleton-loading stack — and, at 19:40 EDT tonight, your blanket approval: every approved PR is merged, migration 0047 and the 13,587-row USDA seed are on production, '
 'and the branches are swept. Automated evidence is in the last two sections; the middle sections are the checks only you can run on a phone, in a console, or as a decision.')
S['stats']['unit']='3,413 tests (final pre-merge tree) · CI green on main at 03077b4'
S['changes_intro']=(f'{total} pull requests merged since Sep 3, grouped by the wave they belonged to. Every one went through an advocate + critic review pair before merge. '
 'Tonight\'s wave is first: read each PR for what it changes, then find its manual rows under "What only you can test".')
approval={'name':'Approval wave (Sep 5 evening)','prs':[193,196,198,197,182,185,156],
 'blurb':('At 19:40 EDT you approved everything. Merged in dependency order: the skeleton-loading spec (#193) and its three PRs (#196 primitives, timing hook, launch gate, Pantry/Location/Lists; '
  '#198 recipes, community, cook mode, folders, creator profile; #197 Profile slots, Item, Expiring, Zones, Insights, Recent, review lists, receipt wait), spec 23 one paid tier (#182), '
  'spec 57 email verification (#185), and the USDA nutrition matcher (#156) after its migration 0047 and seed went to production. Each dependent PR was retargeted to main and re-stacked on the squash '
  'below it before merging; every merged head had its own green CI run. What to review in depth: the skeleton rules (150 ms delay, 300 ms minimum, Reduce Motion, one announcement), '
  'the spec 23 contracts you decided last night (price, trial, welcome grant, lapse), spec 57\'s strict gate, and spec 45\'s fail-open nutrition fill on the shelf-life route.')}
S['waves']=[w for w in S['waves'] if w['name']!=approval['name']]; S['waves'].insert(0,approval)
S['actions_intro']=('In order. 0054, 0053, 0047 and the USDA seed are on production (asserts live). What is left is consoles, secrets, builds, a phone, and four decisions. '
 'Items 1–3 use your credentials or your console; I take over again right after each.')
A=[]
def act(title,detail,command=None):
    d={'title':title,'detail':detail}
    if command: d['command']=command
    A.append(d)
old={a['title']:a for a in S['actions']}
rot=old.get('Rotate the Neon neondb_owner password',{}).get('detail','')
act('Rotate the Neon neondb_owner password', rot+' AFTER rotating: put the new owner connection strings into ~/agents/.env.acceptance on the mini (chmod 600; the NEON_DIRECT_URL and NEON_BRANCH_DIRECT_URL lines) — never in chat — and update the Worker\'s NEON_DATABASE_URL secret if it uses that role. Until then I have no database access, so do the two console steps below in the same sitting.',
    'chmod 600 ~/agents/.env.acceptance && $EDITOR ~/agents/.env.acceptance   # replace NEON_DIRECT_URL / NEON_BRANCH_DIRECT_URL')
act('Sign the Neon CLI in on the mini (one time)', 'You asked for the Neon skills (neon, neon-postgres) — installed tonight, project-scoped. The CLI has no account on this machine (profile DEFAULT, account "-"), so it cannot reach your project. One `neon auth` in a terminal on the mini (browser sign-in) fixes that; an API key in the env file (NEON_API_KEY=…) is the alternative. Then I can list branches, reset roles and check the Auth integration without the console.',
    'cd ~/code/pantry && npx neon@latest auth && npx neon@latest profile list')
dis=old.get('Disable Neon Managed Auth and delete the old Supabase project',{}).get('detail','')
act('Disable Neon Managed Auth, then say so; delete the old Supabase project', dis+' After you disable it I cut a branch from production, rehearse 0055 (expects ALL 9 ASSERTIONS PASSED), apply, and merge #194 — already rebased onto tonight\'s main and green. Production tonight: neon_auth exists, owned by role neon_auth, tables empty except jwks 1 · verification 4 · project_config 1.')
dep=old.get('Deploy the Worker',{})
act('Deploy the Worker', dep.get('detail','')+' New since the last deploy: spec 45\'s fail-open USDA nutrition fill on the shelf-life route (reads usda_foods as table owner; answers gain nutrition_filled). Until deployed, the route behaves exactly as before.', dep.get('command'))
eas=old.get('Cut a new EAS development build',{})
act('Cut a new EAS development build', 'app.json gained the webcredentials association (#174) and the JS bundle now carries the whole skeleton stack; the installed dev client runs the old runtime until this is done. Do it before the device pass.', eas.get('command'))
act('Device pass', 'Three scripts, all under "What only you can test" below: spec 58 rows 1–6 (launch gate → Pantry handoff with no blank frame and one announcement; Profile slots at 150 ms; Reduce Motion static fills; VoiceOver "Loading community" once; dark-mode block contrast; large-text row heights), spec 45\'s two rows (a generic item you type in that OFF does not know gets a USDA panel on the item screen; a barcoded product never does), and the untouched runbook scenarios (second account/RLS, cellular sign-up, camera).')
for t in ['Anthropic console budget alert','Sentry (ADR D13)','RevenueCat go-live gate','Raise the Data API auth.uid() race with Neon support']:
    if t in old: A.append(old[t])
act('Four decisions', '(1) PR #176 (specs 55/56 Obsidian + Codex lane) stays parked per your note — it now conflicts with main; say "un-park" and I rebase it. (2) The Neon skill files (.agents/, .claude/skills/neon*, skills-lock.json) are untracked in the repo: commit them so agents in fresh worktrees get them, or add them to .gitignore. (3) Dependabot #155 (jest 30 · eslint 10 · RNTL 14 · @types/jest 30, CI red) is closed; those majors land as one deliberate upgrade PR when you want it. (4) The gallery: 24 screens × 3 directions still have no picks recorded.')
act('Start the coding waves', 'Specs 23 and 57 are merged. Their implementation (migrations 0060–0063, the Worker paywall/grant/verification routes, the client paywall, sent state and Universal Link) is the next queue for Opus agents — a word from you starts it; nothing else blocks it. Same for any gallery direction you pick and the skeleton follow-ups (D2 household hint, keepPreviousData on the community feed, ConfirmSheet CTA colour).')
S['actions']=A
E=[e for e in S['evidence'] if e[0] not in ('Skeleton loading (spec 58)','Typecheck · lint · jest')]
E.insert(0,['Migration 0047 + USDA seed on production','pass',
 'Applied 2026-09-05 19:48 EDT at your word: 0047 (asserts 7/7 on the empty table), the seed (13,587 rows in 4 s: foundation 363 · sr_legacy 7,793 · survey_fndds 5,431), asserts 7/7 again; the runbook\'s worst-case prefilter ("chicken", 812 survivors → 400) ran in 50.9 ms on production. '
 'One incident, fixed in three minutes and recorded in MIGRATIONS.md: the first grants replay used PR #156\'s pre-0053 copy of db/neon-grants.sql, which re-granted table-level UPDATE on households and INSERT/UPDATE on grocery_items to authenticated (19:48–19:51). 0053\'s suite caught it (N12 FAIL); the three-way-merged file put the column scoping back. Afterwards: 0047 7/7 · 0053 16/16 · 0054 8/8 · 0050 12/12, no client-role privilege on usda_foods, RLS on with zero policies, service_role SELECT only; 2 profiles / 13 inventory rows / 431 catalog rows intact before and after.'])
E.insert(1,['Skeleton loading (spec 58)','pass','Merged 2026-09-05 19:48–20:16 EDT as #193 → #196 → #198 → #197, each re-stacked onto the squash below it with its own green run; 3,477 jest tests on the final stacked tree; bare spinner sites 38 → 14, the remainder pinned by tests/spinner-ratchet.test.ts; the device rows are spec 58 rows 1–6 below.'])
E.insert(2,['Typecheck · lint · jest','pass','CI green on main at 03077b4 (push runs at e304ff7, 0faefd4 and 03077b4 all green); every PR merged tonight had the full suite plus the four-timezone re-run green on its rebased head; secret scan and disclosures green.'])
E.append(['Branch and worktree hygiene','pass','44 local branches deleted after a bundle backup (~/agents/backups/pantry-local-branches-2026-09-05.bundle); stale remote-tracking refs pruned; the two closed-PR remote branches (#58, #97) deleted; origin now holds main plus the branches of #194 and #176; no agent worktrees remain.'])
S['evidence']=E
S['open_items']=[
 'PR #194 (migration 0055: drop the empty legacy neon_auth schema) — rebased onto tonight\'s main and green; waits for you to disable Neon Managed Auth, then I rehearse, apply and merge.',
 'PR #176 (specs 55/56) — parked per your note; now conflicting with main (board + ADR index); rebased on your word.',
 'PR #155 (Dependabot majors) — closed tonight with a note; jest 30 / eslint 10 / RNTL 14 / @types/jest 30 land as one deliberate upgrade PR.',
 'Spec 23 (one paid tier) and spec 57 (email verification) implementation — specs merged; migrations 0060–0063 reserved; the coding waves run on Opus agents on your go.',
 'Screen directions gallery — 24 screens × (Today + 3 directions); no picks recorded yet.',
 'Design and skeleton follow-ups queued: ConfirmSheet CTA colour (design-system rule 2); spec 28 reset mail via app_auth.email_sends; D2 household hint on the launch gate; keepPreviousData on the community feed; the Icon act() warnings in other suites.',
 'Neon Data API auth.uid() race — defended by #191\'s retry; the support ticket is yours (reproduction in the actions above).',
 'Neon skills (neon, neon-postgres) installed at your request — untracked in the repo until you decide; the CLI still needs your sign-in.',
]
json.dump(S,open(P,'w'),ensure_ascii=False,indent=1); print('summary.json updated:', S['as_of'], '| actions', len(A), '| waves', len(S['waves']), '| evidence', len(E), '| open', len(S['open_items']))
