---
title: pantry specs 50+51 build plan (2026-09-04)
type: note
permalink: agents/projects/plans/pantry-specs-50-51-build-plan-2026-09-04
---

# Build plan — spec 50 (moderation + /admin) and spec 51 (creator profiles)
_Produced 2026-09-04 by a read-only planning agent on the mini for the production-readiness program. NOT implemented: Everett's "recipes feature spec" chat owns specs 47–53 (it pushed spec 52/53 amendments to main the same night), so this plan is a handoff, not a work order. Verify against the specs' current text before use._

## Shape
- PR A `feat/report-lifecycle`: migration **0053_report_lifecycle.sql** (recipe_reports gains status/resolved_at/resolved_by/resolution_note + paired CHECK + partial open index; column-scoped INSERT (recipe_id, reporter_id, reason); new `admin_audit_log` with RLS on, zero policies, zero client grants) + `db/asserts/0053_…` N1–N10 + grants tail + types + docs. Zero client change; dark-safe.
- PR B `feat/creator-profiles` (on A): migration **0054_creator_profiles.sql** (profiles.bio ≤280 with `profiles_bio_len`; profiles.links jsonb default [] validated by IMMUTABLE `profile_links_valid()` (≤3 items, {label ≤30, url ≤300 https-only}, text ≤1200 — the spec's 600 cannot hold three real links); `profiles_select` back to `using (true)` with the column grant widened to (id, display_name, avatar_url, created_at, bio, links) — push token/timezone/digest columns stay ungranted (ADR recipes D3 supersession, staged 08-29); `profile_reports` with the 0053 lifecycle shape, insert-only, not-self) + P1–P10 asserts + **amend db/asserts/0046 F10** (it asserts profiles_select is NOT `true`) + client: repo seam `profile / updateMyProfile / publicRecipesBy / reportProfile` (+ broadcast.test SILENT map entries), pure `profileLinks.ts`, hooks, `Avatar`, `CommunityCard` extraction with byline button + accessibility action, `StatsRow`, `LinkRow`, `ProfileEditor`, screens `profile/[id]` and `profile/edit`, Profile-tab row, recipe-detail byline; `ReportSheet subject`; Maestro `51-profiles.yaml` (single-account golden path, leaves nothing behind); docs (README row, MIGRATIONS block, spec §History, ADR D3 landed + O-entries, ACCEPTANCE_TESTS scenario 51, checklist/test-plan rows, SPEC.md, community.md note).
- PR C `feat/admin-dashboard` (on B; Everett's "build now" call): `/admin` on the Worker — session via Better Auth `getSession`, `ADMIN_USER_IDS` secret (absent = byte-identical 404), same-origin form POSTs (Origin check = CSRF line), every mutation + audit row in ONE transaction (`sql.begin`), queue UNION over recipe/profile(/comment via to_regclass) reports, recipe/profile/users/audit pages as string-composed HTML via `_shared/invite.ts` page()/escapeHtml, no client JS; route tests with mocked db/auth; deploy order: apply 0053+0054 → `wrangler deploy` → `secret put ADMIN_USER_IDS`.

## Gotchas the plan surfaced
- **Nothing in the app writes `profiles.avatar_url`** (only the type files mention it) — spec/PRD's "existing avatar editor" does not exist; render https avatars with an initials fallback, ship no editor (spec's own out-of-scope), or spec an upload reusing `POST /photos/upload`.
- 0046's F10 assert will fail after 0054 (it pins profiles_select ≠ true) — amend the assert file (migrations are immutable, asserts are not).
- `UPDATE` on profiles stays table-level (0046 SCH-20 accepted) — the spec's "column-scoped UPDATE" clause is a deviation to record, not to implement.
- New PantryRepository methods must be classified in `src/features/data/broadcast.test.ts`'s SILENT map or the suite fails; `database.types.ts` is hand-edited.
- `tests/migrations-registered.test.ts` reads only the FIRST bash block of MIGRATIONS.md §Pending applies — 0053 and 0054 share one block in numeric order.
- Apply-before-merge is load-bearing for PR B (the new client names bio/links → 42703 on an un-migrated DB); PR A is dark-safe both ways.
- `reportProfile` returns 'already_reported' on 23505 (spec wants the copy), unlike `reportRecipe`'s silent no-op.
- The Worker's `/admin` login must proxy `/auth/sign-in/email` (JSON endpoint) server-side to stay JS-free and same-origin; rate-limit with the invite pattern.

Full plan text (DDL, assert lists, route table, file-by-file client changes) is in the mini session scratchpad `scratchpad/plan-50-51.md` while that session lives; regenerate with the same brief if lost.
