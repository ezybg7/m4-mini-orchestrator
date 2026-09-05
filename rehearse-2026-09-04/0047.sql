-- 0047: the server-only USDA FoodData Central mirror
-- (specs/catalog-nutrition-matching.md, spec 45).
--
-- ADR: docs/adr/catalog.md — D4's amendment (nutrition is two-source: a row WITH
-- a barcode is a product and carries OFF's panel; a row with NO barcode is
-- generic and may carry a USDA FDC panel), D5 (catalog writes are server-only),
-- O1's revision (Everett's standing intent: every food entry carries a label).
-- Contradicting an active entry there is a PR-description escalation.
--
-- NUMBER. Reserved as 0045 when spec 45 was written, renumbered 0045 → 0047 on
-- 2026-08-22 because `0045_invite_links.sql` took that number on main and was
-- applied to production on 2026-08-13 (later merger renumbers, per the rule at
-- the foot of the registry table); 0046 was skipped because the db-hardening
-- lane had claimed it. This table references nothing but itself, so the
-- stale-reservation trap that caught 0006/0022/0009 cannot bite it.
--
-- WHAT THIS IS FOR. The USDA backfill tranches (`db/apply/usda-nutrition-*.sql`)
-- were a ONE-SHOT over the 421-row seed catalog. A catalog row created AFTER
-- that snapshot — `source = 'user'` (a barcoded product OFF didn't know) or
-- `source = 'ai'` (a generic food the shelf-life estimator invented) — is born
-- with `nutrition = null` and nothing ever fills it. This table is the standing
-- path: a DB-resident slim copy of FDC that `workers/src/routes/shelfLife.ts`
-- name-matches those rows against at the moment they enter the system, stamping
-- the winning panel `nutrition_source = 'usda'`.
--
--   * No AI number is ever invented — the match is deterministic (`matchCatalog`
--     via `supabase/functions/_shared/usdaMatch.ts`, same thresholds as every
--     other catalog match) and the panel is a lab-analysed FDC figure. A
--     below-threshold match ABSTAINS and the row stays null, because a missing
--     number stays visibly missing while a wrong-but-plausible one would not.
--   * No runtime FDC API. The data is offline, versioned, and public domain (US
--     federal government work — no attribution or share-alike obligation, unlike
--     OFF's CC-BY-SA), so holding 13.6k rows costs one apply and no key
--     management, no rate limit, and no third party in the request path.
--   * Barcoded rows are STRICT-NULL and this table is never consulted for them
--     (Everett 2026-08-22, ADR O1's residual choice): a barcode names one
--     manufactured product, so its panel comes from OFF or it does not exist.
--     That guard lives in the Worker's UPDATE, not here.
--
-- WHO READS IT. Only the Worker, as the table owner through NEON_DATABASE_URL.
-- Clients never query FDC data — they read the copied panel off `catalog_items`
-- like always. The posture is `push_tickets`' (0044) verbatim: RLS enabled with
-- ZERO policies, and not one privilege granted to any client role.
--
-- SEED DATA SHIPS SEPARATELY. This migration creates an EMPTY table; the ~13.6k
-- rows arrive as `db/apply/usda-foods-seed.sql`, generated offline by
-- `scripts/usda-match/export-usda-foods.py` from the three committed-by-URL FDC
-- datasets and applied by hand like every other `db/apply/` artifact. The
-- Worker's matching path is fail-open, so the window between this apply and that
-- one is a no-op rather than an error (see §Pending applies).
--
-- PORTABILITY (specs/MIGRATIONS.md): schema-qualified throughout, no
-- `auth.users`, no `realtime.*`, privileges granted by revoking from PUBLIC
-- rather than naming the unauthenticated role (Supabase `anon`, Neon
-- `anonymous`). 0044 is the worked example this file follows.
--
-- Verify on a Neon branch with db/asserts/0047_usda_foods.sql, then apply to
-- production by hand against the DIRECT endpoint — there is no runner.

create table public.usda_foods (
  -- FDC's own identifier, and the reason this table needs no surrogate key: it
  -- is stable across dataset releases, which is what makes a re-export an
  -- idempotent upsert (`on conflict (fdc_id) do update`) rather than a reload.
  fdc_id integer primary key,

  -- The FDC description verbatim, comma-inverted as the source writes it
  -- ("Flour, wheat, all-purpose, enriched, bleached"). The matcher reads BOTH
  -- halves of it: the first two comma-segments become the candidate's name and
  -- the whole string becomes its single alias, so a short query can still reach
  -- a long specific entry without the long entry's tail dragging the score down.
  description text not null,

  -- Which dataset the row came from. A CHECK rather than an enum: the value set
  -- is FDC's, not ours — a new dataset (branded, experimental) would be a new
  -- value here, and widening a CHECK is one migration while widening an enum
  -- that other columns may reference is a worse one. `survey_fndds` names the
  -- FNDDS survey dataset, which is the "as consumed" data tranche 2 leaned on.
  data_type text not null
    check (data_type in ('foundation', 'sr_legacy', 'survey_fndds')),

  -- The slim per-100 g panel in EXACTLY the shape the backfill writes and
  -- `Nutrition` (src/lib/types.ts) declares: kcal, fat_g, saturated_fat_g,
  -- carbs_g, sugars_g, fiber_g, protein_g, salt_g, and caffeine_mg only where
  -- the food actually has caffeine. A key is present only where FDC reports the
  -- nutrient, so an ABSENT KEY MEANS UNKNOWN, never zero — which is why the
  -- Worker copies this value verbatim instead of merging it into a template.
  --
  -- `jsonb_typeof(...) = 'object'` is the one shape guarantee worth a CHECK: the
  -- Worker copies this straight into `catalog_items.nutrition`, and a bare
  -- number or array reaching that column would render as a broken label rather
  -- than as an error. There is no serving_size — FDC is mass-based.
  --
  -- `<> '{}'` closes the case the type check alone misses, and it is the worse
  -- one: an empty object IS an object, so it would store, copy across, and land
  -- on `catalog_items` as a NON-NULL blank panel — permanently blocking, because
  -- the fill path's own `nutrition is null` guard can never revisit it, and
  -- rendering as a broken card rather than the honest "No nutrition info
  -- available for this food." placeholder. The generator already skips foods
  -- whose panel came out empty; this is what makes that a guarantee rather than
  -- a convention two files apart.
  nutrition jsonb not null
    check (jsonb_typeof(nutrition) = 'object' and nutrition <> '{}'::jsonb),

  -- When the seed apply last wrote this row. Bumped by the upsert, so "which
  -- dataset release is live" is answerable without diffing the file.
  imported_at timestamptz not null default now(),

  -- 0029's rule for text columns, applied here even though NOTHING user-written
  -- reaches this table: the generator truncates to this length, so the cap is
  -- the contract between the two files rather than a defence against a user.
  -- FNDDS carries the long ones; 300 clears the longest real description with
  -- room to spare.
  --
  -- NOT in `src/lib/limits.test.ts`'s list, and the absence is deliberate: that
  -- guard exists so a client `maxLength` and a database CHECK cannot drift
  -- apart, and there is no client counterpart here — no client role can write
  -- (or even read) this table. The counterpart is the Python generator, and the
  -- assert suite's U1 is what pins the two together.
  constraint usda_foods_description_len check (char_length(description) <= 300)
);

-- NO INDEX ON `description`, deliberately — and the cost is worth stating
-- honestly rather than as "just a seq scan", because it is more than that.
--
-- The one read is the Worker's token prefilter, and its full shape is:
--
--   where description ilike any(array['%oat%', ...])          -- N patterns
--   order by (select count(*) from unnest(array[...]) t
--              where description ilike t) desc,               -- correlated,
--            length(description), fdc_id                      -- per SURVIVOR
--   limit 400
--
-- So the real work is: one sequential scan over ~13.6k rows evaluating up to N
-- ILIKE patterns each, then a correlated `unnest` count re-evaluating those N
-- patterns for every row that SURVIVED the filter, then a sort. N is the count
-- of three-plus-character tokens in the food's name — usually 1–3, but a
-- 300-character catalog name (0029's cap) could reach ~30, and a generic token
-- like "chicken" makes the survivor set large, which is exactly when the
-- correlated subquery costs most.
--
-- It is still the right call, for reasons no index changes: a leading-`%`
-- pattern is not btree-servable, so the only index that would help is a pg_trgm
-- GIN one — an extension this schema does not otherwise use — and this runs on a
-- fire-and-forget background route, at most once per distinct unknown food per
-- invocation, bounded by the route's existing MAX_MODEL_CALLS of 20, behind a
-- model call that costs orders of magnitude more. Nobody is waiting on it, and
-- it never runs on a user-facing read path.
--
-- MEASURE IT AT REHEARSAL rather than trusting this comment: specs/MIGRATIONS.md
-- §Pending applies carries an `explain (analyze, buffers)` line for the worst
-- case ("chicken", the largest survivor set) to run against the seeded table. If
-- that comes back slow, the fix is the pg_trgm index, not a smaller cap — the
-- cap is a recall guarantee. If the table ever grows past FDC's generic datasets
-- (branded foods are ~2M rows) the trade flips outright, and the flip is its own
-- migration.

comment on table public.usda_foods is
  'Spec 45: server-only slim mirror of USDA FoodData Central (Foundation '
  '2026-04-30, SR Legacy 2018-04, FNDDS survey 2024-10-31) — per-100 g panels in '
  'the Nutrition shape, keyed by fdc_id. Read by the Worker''s shelf-life route '
  'to name-match `user`/`ai` catalog rows born after the backfill snapshot. RLS '
  'on with no policies and no client grants; the Worker owns every row. Seeded '
  'by db/apply/usda-foods-seed.sql, generated offline — no runtime FDC API.';

alter table public.usda_foods enable row level security;

-- No policies. Not an omission — see the header. A table with RLS enabled and no
-- policy is closed to every role that is not its owner, which is exactly the
-- posture for reference data the client must never query directly (0044's
-- `push_tickets` is the precedent, and its comment says the same).

-- Grants: revoke from PUBLIC per 0023, and grant nothing to any client role.
-- `authenticated` holding SELECT here would be harmless to privacy and wrong
-- anyway: it would publish a second, un-curated nutrition surface next to
-- `catalog_items`, and the whole point of D4's amendment is that there is one
-- panel per food and one place to read it.
revoke all on table public.usda_foods from public;

do $$
begin
  -- Supabase only; Neon has no such role. Read-only there — the seed apply and
  -- the Worker both connect as the table owner, so nothing the service identity
  -- does needs to write this table.
  if exists (select 1 from pg_roles where rolname = 'service_role') then
    grant select on table public.usda_foods to service_role;
  end if;
end $$;
