-- ============================================================================
-- Assertions for the AI quota RPCs (migration 0027, as re-created by 0042,
-- 0043 and 0070). Audit 2026-08-22, finding TST-04: `claim_ai_call` is the only
-- thing standing between an open signup and the provider bill — 0027 exists
-- because a live probe beat a cap of 20 with 40 concurrent requests — and until
-- then nothing exercised it. 0043's A11 reads the function's TEXT for the pool
-- mapping, which catches a deleted bucket and nothing else: it would pass on a
-- function that never refused anybody.
--
-- These are BEHAVIOURAL. They call the RPC and read the verdict.
--
-- 2026-09-14, migration 0070 (specs/monetization.md §Migrations 0070): G6–G16
-- are the per-kind-pool cases. This file is the pools' subject, so the new
-- cases extend it rather than starting a file of their own.
--
-- GUI edition, per db/apply/check-0038-gui.sql: one row back, because the Neon
-- SQL Editor discards notices and a pass and a failure looked identical.
--
--   psql "$NEON_BRANCH_DIRECT_URL" -f db/asserts/0027_ai_quota.sql
--
-- You get back:
--
--     result
--     -----------------------------------------
--     ALL 16 ASSERTIONS PASSED
--   or
--     FAILED [errcode]: G3 FAIL: a claim over the daily cap still inserted a row
--
-- Everything runs inside a transaction this script rolls back itself, so it is
-- safe to re-run and leaves no rows behind.
--
-- WHY IT SEEDS ITS OWN PROFILES. `ai_calls.user_id` is a FK to `profiles`,
-- which hangs off `app_auth."user"` — and a SQL session cannot fake an identity
-- on Neon (`auth.uid()` is a C function reading the request's GUCs; see
-- db/asserts/0038_sweep_adds_to_list.sql's header). `claim_ai_call` takes the
-- user id as an ARGUMENT, though, so it can be called directly as the table
-- owner. Until 0070 this file metered whatever profile it found first, with the
-- caps computed from that user's own current counts; the pool cases need
-- several users whose ledgers are known to be EMPTY and cannot be rehearsed at
-- all on the rehearsal project, which carries production's schema and no rows.
-- So each group inserts its own `app_auth."user"` and lets the signup trigger
-- make the profile — the 0067 technique. Every row written here is rolled back.
-- Where identity genuinely blocks a check (the ACL, which is about roles the
-- session is not), the catalog is read instead, in the 0043 style.
--
-- WHAT IT STILL CANNOT DO. One session cannot race itself, so the advisory lock
-- that closes 0027's TOCTOU is pinned as TEXT (G16), not executed — the 0052
-- M11 technique. A real two-caller race needs the Node probe pattern of
-- db/asserts/0068_user_follows_concurrency.sh.
-- ============================================================================

begin;

create function pg_temp.check_0027() returns text language plpgsql as $fn$
declare
  v_user    uuid;
  v_u2      uuid;
  v_u2b     uuid;
  v_u3      uuid;
  v_u4      uuid;
  v_u5      uuid;
  v_u6      uuid;
  v_u7      uuid;
  v_u8      uuid;
  v_u9      uuid;
  v_daily   int;
  v_monthly int;
  v_res     jsonb;
  v_claim   uuid;
  v_n       int;
  v_i       int;
  v_role    text;
  v_src     text;
  v_start1  timestamptz;
  v_start2  timestamptz;
  v_reset1  text;
begin
  -- G1. THE ACL, through a fourth re-creation of the function. These two bypass
  -- RLS on the billing ledger and take the caps as arguments, so a client role
  -- holding EXECUTE would be able to name its own limit. Read from the catalog:
  -- the session is neither role.
  for v_role in select rolname from pg_roles
                 where rolname in ('anon', 'anonymous', 'authenticated') loop
    if has_function_privilege(v_role, 'public.claim_ai_call(uuid, text, int, int, int)', 'execute') then
      raise exception 'G1 FAIL: % can execute claim_ai_call and choose its own cap', v_role;
    end if;
    if has_function_privilege(v_role, 'public.refund_ai_call(uuid, uuid)', 'execute') then
      raise exception 'G1 FAIL: % can execute refund_ai_call and erase its own usage', v_role;
    end if;
  end loop;
  if exists (select 1 from pg_roles where rolname = 'service_role')
     and not has_function_privilege('service_role', 'public.claim_ai_call(uuid, text, int, int, int)', 'execute') then
    raise exception 'G1 FAIL: service_role cannot execute claim_ai_call — every AI route is down';
  end if;
  raise notice 'G1 ok: both quota RPCs are service-role only';

  insert into app_auth."user" (name, email, "emailVerified", "updatedAt")
  values ('Quota G1', 'assert-0027-g1@ambry.invalid', false, now()) returning id into v_user;
  if not exists (select 1 from public.profiles p where p.id = v_user) then
    raise exception 'G1 FAIL: the signup trigger made no profile to meter against';
  end if;

  -- G2. UNDER THE CAP, THE LEDGER ROW IS THE PERMIT. 0027's whole shape: the
  -- claim does not merely say yes, it writes the row that makes the next
  -- caller's count higher. A verdict without a row would be the TOCTOU 0027
  -- was written to close.
  v_res := public.claim_ai_call(v_user, 'receipt', 1, 1, 1);
  v_claim := (v_res ->> 'claim_id')::uuid;
  if v_claim is null then
    raise exception 'G2 FAIL: a claim under both caps was refused (%)', v_res;
  end if;
  if v_res ->> 'exhausted' is not null then
    raise exception 'G2 FAIL: an accepted claim reported exhausted=%', v_res ->> 'exhausted';
  end if;
  select count(*) into v_n from public.ai_calls c
   where c.id = v_claim and c.user_id = v_user and c.kind = 'receipt';
  if v_n <> 1 then
    raise exception 'G2 FAIL: the claim id names no ledger row — the permit was not written';
  end if;
  -- The verdict the Worker renders (workers/src/routes/receipt.ts): every key
  -- the 429 and 200 paths read.
  if not (v_res ? 'plan' and v_res ? 'used' and v_res ? 'limit'
          and v_res ? 'remaining' and v_res ? 'resets_at' and v_res ? 'exhausted') then
    raise exception 'G2 FAIL: the verdict is missing a key the Worker reads (%)', v_res;
  end if;
  if (v_res ->> 'used')::int <> 0 then
    raise exception 'G2 FAIL: used is %, expected the pre-claim count 0', v_res ->> 'used';
  end if;
  raise notice 'G2 ok: an under-cap claim returns a claim_id and inserts exactly that row';

  -- G3. AT THE DAILY CAP: the documented 429 shape, and NO row.
  select count(*) into v_daily from public.ai_calls c
   where c.user_id = v_user and c.created_at >= now() - interval '24 hours';
  select count(*) into v_n from public.ai_calls c where c.user_id = v_user;

  v_res := public.claim_ai_call(v_user, 'receipt', 9999, 9999, v_daily);
  if v_res ->> 'exhausted' is distinct from 'daily' then
    raise exception 'G3 FAIL: at the daily cap the verdict was exhausted=%',
      coalesce(v_res ->> 'exhausted', 'null');
  end if;
  if v_res ->> 'claim_id' is not null then
    raise exception 'G3 FAIL: a refused claim still returned a claim id';
  end if;
  if v_res ->> 'resets_at' is null or v_res ->> 'plan' is null then
    raise exception 'G3 FAIL: the 429 verdict is missing the fields the client renders';
  end if;
  select count(*) into v_monthly from public.ai_calls c where c.user_id = v_user;
  if v_monthly <> v_n then
    raise exception 'G3 FAIL: a claim over the daily cap still inserted a row';
  end if;
  raise notice 'G3 ok: over the daily cap — exhausted=daily, no claim id, no ledger row';

  -- G4. MONTHLY BEFORE DAILY, and only for kinds that are in a pool. A user at
  -- both limits must see "upgrade", not "wait until tomorrow"
  -- (specs/monetization.md §Quota semantics) — so this passes a daily cap of 0
  -- as well, and still expects `monthly`.
  select count(*) into v_monthly from public.ai_calls c
   where c.user_id = v_user and c.kind in ('receipt', 'photo')
     and c.created_at >= (date_trunc('month', now() at time zone 'utc') at time zone 'utc');

  v_res := public.claim_ai_call(v_user, 'receipt', v_monthly, v_monthly, 0);
  if v_res ->> 'exhausted' is distinct from 'monthly' then
    raise exception 'G4 FAIL: at both limits the verdict was exhausted=%, expected monthly',
      coalesce(v_res ->> 'exhausted', 'null');
  end if;
  if (v_res ->> 'remaining')::int <> 0 then
    raise exception 'G4 FAIL: remaining is % at an exhausted monthly quota', v_res ->> 'remaining';
  end if;
  -- …and a kind with NO monthly pool is never refused for a full quota, only
  -- for the abuse cap. After 0070 that is the two FETCH kinds only —
  -- `shelf_life` has a pool of its own (G11).
  v_res := public.claim_ai_call(v_user, 'import_fetch', 0, 0, 5);
  if v_res ->> 'claim_id' is null then
    raise exception 'G4 FAIL: an unpooled kind was refused for a full monthly quota (%)', v_res;
  end if;
  v_res := public.claim_ai_call(v_user, 'barcode_fetch', 0, 0, 5);
  if v_res ->> 'claim_id' is null then
    raise exception 'G4 FAIL: barcode_fetch was refused for a full monthly quota (%)', v_res;
  end if;
  raise notice 'G4 ok: monthly is decided before daily, and only for pooled kinds';

  -- G5. THE REFUND IS SCOPED TO THE OWNER. "Charge on success only" (ADR
  -- monetization D4) means the row exists only for the duration of the attempt
  -- — but a refund that took a claim id alone would let one caller delete
  -- another user's ledger row and un-bill them. `v_claim` is still the row G2
  -- wrote.
  perform public.refund_ai_call(gen_random_uuid(), v_claim);
  select count(*) into v_n from public.ai_calls c where c.id = v_claim;
  if v_n <> 1 then
    raise exception 'G5 FAIL: a refund from the wrong user deleted the row';
  end if;
  perform public.refund_ai_call(v_user, v_claim);
  select count(*) into v_n from public.ai_calls c where c.id = v_claim;
  if v_n <> 0 then
    raise exception 'G5 FAIL: the owning user''s refund left the row in place';
  end if;
  raise notice 'G5 ok: a refund removes the claim only for the user who made it';

  -- ==========================================================================
  -- 0070 — the per-kind pools. Each group gets its own user so every count in
  -- it starts at zero and the arithmetic is exact.
  -- ==========================================================================

  -- G6. BARCODE IS ON NO COUNTER A USER CAN HIT (the L9 bug, as a test; ADR D1,
  -- Everett 2026-09-13). Under 0043's kind-agnostic daily count, 21 unknown
  -- barcodes in a day killed receipt scanning for 24 hours.
  insert into app_auth."user" (name, email, "emailVerified", "updatedAt")
  values ('Quota G6', 'assert-0027-g6@ambry.invalid', false, now()) returning id into v_u2;
  insert into public.ai_calls (user_id, kind, item_count)
  select v_u2, 'barcode_fetch', 0 from generate_series(1, 50);

  foreach v_src in array array['receipt', 'photo', 'import', 'ideas', 'shelf_life'] loop
    v_res := public.claim_ai_call(v_u2, v_src, 9999, 9999, 20);
    if v_res ->> 'claim_id' is null then
      raise exception 'G6 FAIL: 50 barcode_fetch rows refused a % claim (%)', v_src, v_res;
    end if;
    perform public.refund_ai_call(v_u2, (v_res ->> 'claim_id')::uuid);
  end loop;

  -- …and the other direction, on a user whose barcode pool is untouched: a full
  -- day of the AI pool still answers a barcode lookup, because `barcode_fetch`
  -- counts only itself.
  insert into app_auth."user" (name, email, "emailVerified", "updatedAt")
  values ('Quota G6b', 'assert-0027-g6b@ambry.invalid', false, now()) returning id into v_u2b;
  insert into public.ai_calls (user_id, kind, item_count)
  select v_u2b, 'receipt', 0 from generate_series(1, 20);
  v_res := public.claim_ai_call(v_u2b, 'barcode_fetch', 0, 0, 50);
  if v_res ->> 'claim_id' is null then
    raise exception 'G6 FAIL: a day of receipt scans refused a barcode lookup (%)', v_res;
  end if;
  raise notice 'G6 ok: barcode_fetch spends nothing a user can hit, in either direction';

  -- G7. SHELF-LIFE'S DAILY POOL IS ITS OWN, BOTH WAYS. `maybeRequestShelfLife`
  -- fires once per add batch, so twenty singly-entered unknown foods used to
  -- spend the receipt path's whole day before the welcome evening's first scan.
  insert into app_auth."user" (name, email, "emailVerified", "updatedAt")
  values ('Quota G7', 'assert-0027-g7@ambry.invalid', false, now()) returning id into v_u3;
  insert into public.ai_calls (user_id, kind, item_count)
  select v_u3, 'shelf_life', 0 from generate_series(1, 20);
  v_res := public.claim_ai_call(v_u3, 'receipt', 9999, 9999, 20);
  if v_res ->> 'claim_id' is null then
    raise exception 'G7 FAIL: 20 shelf_life claims refused the evening''s first scan (%)', v_res;
  end if;
  -- shelf_life at its own daily cap refuses ITSELF.
  v_res := public.claim_ai_call(v_u3, 'shelf_life', 100, 100, 20);
  if v_res ->> 'exhausted' is distinct from 'daily' then
    raise exception 'G7 FAIL: shelf_life at 20/day was not refused daily (%)', v_res;
  end if;

  insert into app_auth."user" (name, email, "emailVerified", "updatedAt")
  values ('Quota G7b', 'assert-0027-g7b@ambry.invalid', false, now()) returning id into v_u4;
  insert into public.ai_calls (user_id, kind, item_count)
  select v_u4, 'receipt', 0 from generate_series(1, 20);
  v_res := public.claim_ai_call(v_u4, 'shelf_life', 100, 100, 20);
  if v_res ->> 'claim_id' is null then
    raise exception 'G7 FAIL: a day of scans refused a shelf-life estimate (%)', v_res;
  end if;
  raise notice 'G7 ok: shelf_life and the AI pool no longer spend each other''s day';

  -- G8. ONE IMPORT COSTS ONE DAILY UNIT (the double-unit bug, as a test). An
  -- import that made an outbound fetch used to write two rows into one pool.
  insert into app_auth."user" (name, email, "emailVerified", "updatedAt")
  values ('Quota G8', 'assert-0027-g8@ambry.invalid', false, now()) returning id into v_u5;
  insert into public.ai_calls (user_id, kind, item_count)
  select v_u5, 'import_fetch', 0 from generate_series(1, 20);
  v_res := public.claim_ai_call(v_u5, 'import', 300, 150, 20);
  if v_res ->> 'claim_id' is null then
    raise exception 'G8 FAIL: 20 import_fetch rows refused an import (%)', v_res;
  end if;
  -- import_fetch at its own cap refuses itself.
  v_res := public.claim_ai_call(v_u5, 'import_fetch', 0, 0, 20);
  if v_res ->> 'exhausted' is distinct from 'daily' then
    raise exception 'G8 FAIL: import_fetch at 20/day was not refused daily (%)', v_res;
  end if;
  raise notice 'G8 ok: import_fetch has its own day; one import costs one AI unit';

  -- G9. EACH NON-AI KIND REFUSES ITSELF AT THE CAP ITS ROUTE PASSES —
  -- barcode_fetch 50 (CATALOG_DAILY_CAP), shelf_life 20, import_fetch 20. The
  -- pools narrowed; the abuse bound did not go away.
  v_res := public.claim_ai_call(v_u2, 'barcode_fetch', 0, 0, 50);
  if v_res ->> 'exhausted' is distinct from 'daily' then
    raise exception 'G9 FAIL: barcode_fetch at 50/day was not refused daily (%)', v_res;
  end if;
  raise notice 'G9 ok: barcode_fetch at CATALOG_DAILY_CAP refuses itself (with G7, G8)';

  -- G10. THE MONTHLY POOLS DO NOT CROSS. `import` leaving the scans pool is the
  -- one behavioural change to live semantics in 0070.
  insert into app_auth."user" (name, email, "emailVerified", "updatedAt")
  values ('Quota G10', 'assert-0027-g10@ambry.invalid', false, now()) returning id into v_u6;
  insert into public.ai_calls (user_id, kind, item_count) values (v_u6, 'import', 0);
  v_res := public.claim_ai_call(v_u6, 'receipt', 2, 300, 20);
  if (v_res ->> 'used')::int <> 0 then
    raise exception 'G10 FAIL: an import row advanced the scans count to % (%)',
      v_res ->> 'used', v_res;
  end if;
  perform public.refund_ai_call(v_u6, (v_res ->> 'claim_id')::uuid);
  insert into public.ai_calls (user_id, kind, item_count) values (v_u6, 'receipt', 0);
  v_res := public.claim_ai_call(v_u6, 'import', 300, 150, 20);
  if (v_res ->> 'used')::int <> 1 then
    raise exception 'G10 FAIL: the imports count read % — expected the one import row only (%)',
      v_res ->> 'used', v_res;
  end if;
  -- …and ideas is neither.
  v_res := public.claim_ai_call(v_u6, 'ideas', 3, 100, 20);
  if (v_res ->> 'used')::int <> 0 then
    raise exception 'G10 FAIL: the ideas count read %, expected 0 (%)', v_res ->> 'used', v_res;
  end if;
  raise notice 'G10 ok: scans, imports and ideas each count only their own kinds';

  -- G11. SHELF-LIFE'S MONTHLY POOL — the null pool closed (run-costs finding 3,
  -- AMBR-52). The 101st claim in a calendar month is refused while a scan in
  -- the same month is unaffected; and `p_free_monthly = 0` is the kill switch,
  -- which is the whole reason the Worker PR deploys before this is applied
  -- (§Migrations 0070 §Order, FIND-001).
  insert into app_auth."user" (name, email, "emailVerified", "updatedAt")
  values ('Quota G11', 'assert-0027-g11@ambry.invalid', false, now()) returning id into v_u7;
  insert into public.ai_calls (user_id, kind, item_count)
  select v_u7, 'shelf_life', 0 from generate_series(1, 100);
  v_res := public.claim_ai_call(v_u7, 'shelf_life', 100, 100, 9999);
  if v_res ->> 'exhausted' is distinct from 'monthly' then
    raise exception 'G11 FAIL: the 101st shelf_life claim of the month was not refused monthly (%)',
      v_res;
  end if;
  v_res := public.claim_ai_call(v_u7, 'receipt', 2, 300, 20);
  if v_res ->> 'claim_id' is null then
    raise exception 'G11 FAIL: a month of shelf-life estimates refused a scan (%)', v_res;
  end if;
  v_res := public.claim_ai_call(v_u7, 'shelf_life', 0, 0, 9999);
  if v_res ->> 'exhausted' is distinct from 'monthly' then
    raise exception 'G11 FAIL: SHELF_LIFE_FREE_MONTHLY=0 did not kill shelf-life estimation (%)',
      v_res;
  end if;
  raise notice 'G11 ok: shelf_life is bounded monthly at 100, and 0 is its kill switch';

  -- G12. THE meal_plan POOL (Everett's ruling, 2026-09-13 05:00): its own
  -- monthly pool, the AI kinds' shared daily pool, so the meal-planning spec
  -- ships its route without re-creating this function.
  insert into app_auth."user" (name, email, "emailVerified", "updatedAt")
  values ('Quota G12', 'assert-0027-g12@ambry.invalid', false, now()) returning id into v_u8;
  v_res := public.claim_ai_call(v_u8, 'meal_plan', 1, 20, 20);
  if v_res ->> 'claim_id' is null then
    raise exception 'G12 FAIL: the first meal_plan claim of the month was refused (%)', v_res;
  end if;
  v_claim := (v_res ->> 'claim_id')::uuid;
  -- It advances neither scans nor ideas…
  v_res := public.claim_ai_call(v_u8, 'receipt', 2, 300, 20);
  if (v_res ->> 'used')::int <> 0 then
    raise exception 'G12 FAIL: a meal_plan row advanced the scans count (%)', v_res;
  end if;
  perform public.refund_ai_call(v_u8, (v_res ->> 'claim_id')::uuid);
  v_res := public.claim_ai_call(v_u8, 'ideas', 3, 100, 20);
  if (v_res ->> 'used')::int <> 0 then
    raise exception 'G12 FAIL: a meal_plan row advanced the ideas count (%)', v_res;
  end if;
  perform public.refund_ai_call(v_u8, (v_res ->> 'claim_id')::uuid);
  -- …it is refused at its own monthly limit…
  v_res := public.claim_ai_call(v_u8, 'meal_plan', 1, 20, 20);
  if v_res ->> 'exhausted' is distinct from 'monthly' then
    raise exception 'G12 FAIL: the second meal_plan of the month on free was not refused (%)', v_res;
  end if;
  -- …it spends a unit of the SHARED AI day…
  insert into public.ai_calls (user_id, kind, item_count)
  select v_u8, 'meal_plan', 0 from generate_series(1, 19);
  v_res := public.claim_ai_call(v_u8, 'receipt', 9999, 9999, 20);
  if v_res ->> 'exhausted' is distinct from 'daily' then
    raise exception 'G12 FAIL: 20 meal_plan rows did not spend the shared AI day (%)', v_res;
  end if;
  -- …and a refund gives it back.
  perform public.refund_ai_call(v_u8, v_claim);
  v_res := public.claim_ai_call(v_u8, 'meal_plan', 1, 20, 9999);
  if (v_res ->> 'used')::int <> 19 then
    raise exception 'G12 FAIL: the refund did not return the meal_plan unit (used=%)',
      v_res ->> 'used';
  end if;
  raise notice 'G12 ok: meal_plan has its own month and shares the AI day';

  -- G13. THE MONTH BOUNDARY IS THE SAME IN EVERY SESSION ZONE (0059, folded
  -- here). The enforcement leg is an explicit UTC round trip and the display
  -- leg stays a plain timestamp, so neither depends on the connection's
  -- TimeZone surviving the pooler.
  perform set_config('TimeZone', 'America/Los_Angeles', true);
  -- Compared as timestamptz INSTANTS, never as text: `::text` renders in the
  -- session zone, so two spellings of the same moment would look like a
  -- failure. The instant is what the count filters on.
  select (date_trunc('month', now() at time zone 'utc') at time zone 'utc') into v_start1;
  v_res := public.claim_ai_call(v_user, 'receipt', 0, 0, 20);
  v_reset1 := v_res ->> 'resets_at';
  perform set_config('TimeZone', 'UTC', true);
  select (date_trunc('month', now() at time zone 'utc') at time zone 'utc') into v_start2;
  if v_start2 is distinct from v_start1 then
    raise exception 'G13 FAIL: the enforcement month start moved with the session zone (% vs %)',
      v_start1, v_start2;
  end if;
  v_res := public.claim_ai_call(v_user, 'receipt', 0, 0, 20);
  if v_res ->> 'resets_at' is distinct from v_reset1 then
    raise exception 'G13 FAIL: resets_at differs by session zone (% vs %)',
      v_reset1, v_res ->> 'resets_at';
  end if;
  raise notice 'G13 ok: the month boundary is identical under America/Los_Angeles and UTC';

  -- G14. A KIND IN NO POOL RAISES rather than claiming (FIND-006). 0043's
  -- `else null` is the reason shelf_life went uncharged monthly for four
  -- months; a future migration that adds a kind without a pool decision now
  -- fails its first claim, loudly, in rehearsal.
  begin
    v_res := public.claim_ai_call(v_user, 'not_a_kind', 1, 1, 1);
    raise exception 'G14 FAIL: a kind in no pool returned a verdict (%)', v_res;
  exception
    when raise_exception then
      if sqlerrm not like 'claim_ai_call: no % pool%for kind not_a_kind%'
         and sqlerrm not like 'claim_ai_call: no pool for kind not_a_kind%' then
        raise;
      end if;
  end;
  raise notice 'G14 ok: an unknown kind raises instead of claiming a pool nobody chose';

  -- G15. THE PHOTO ARM'S ATTEMPT BOUND (FIND-003). The photo import arm charges
  -- a recipe-less result, so N charged attempts in a day refuse the N+1th at
  -- the shared AI daily cap — which is the bound that arm now has.
  insert into app_auth."user" (name, email, "emailVerified", "updatedAt")
  values ('Quota G15', 'assert-0027-g15@ambry.invalid', false, now()) returning id into v_u9;
  for v_i in 1..20 loop
    v_res := public.claim_ai_call(v_u9, 'import', 300, 150, 20);
    if v_res ->> 'claim_id' is null then
      raise exception 'G15 FAIL: import % of 20 in a day was refused (%)', v_i, v_res;
    end if;
  end loop;
  v_res := public.claim_ai_call(v_u9, 'import', 300, 150, 20);
  if v_res ->> 'exhausted' is distinct from 'daily' then
    raise exception 'G15 FAIL: the 21st import of the day was not refused daily (%)', v_res;
  end if;
  raise notice 'G15 ok: 20 charged import attempts a day, and the 21st waits';

  -- G16. THE TOCTOU IS STILL CLOSED, through a fourth re-creation. One session
  -- cannot race itself (the 0052 M11 technique), so this pins the installed
  -- body: the advisory lock is taken, and both counts happen after it.
  select p.prosrc into v_src from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'claim_ai_call';
  if v_src is null then
    raise exception 'G16 FAIL: claim_ai_call is not installed';
  end if;
  if position('pg_advisory_xact_lock' in v_src) = 0 then
    raise exception 'G16 FAIL: the re-created body no longer takes the advisory lock';
  end if;
  if position('pg_advisory_xact_lock' in v_src) > position('select count(*)' in v_src) then
    raise exception 'G16 FAIL: a count happens before the lock — the TOCTOU 0027 closed is open';
  end if;
  if position('insert into public.ai_calls' in v_src) < position('pg_advisory_xact_lock' in v_src) then
    raise exception 'G16 FAIL: the permit is written outside the lock';
  end if;
  raise notice 'G16 ok: the count-and-insert still happens inside one advisory lock';

  return 'ALL 16 ASSERTIONS PASSED';
exception
  when others then
    return 'FAILED [' || sqlstate || ']: ' || sqlerrm;
end
$fn$;

select pg_temp.check_0027() as result;

rollback;
