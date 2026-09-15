-- 0070 — per-kind quota pools on BOTH axes (specs/monetization.md §Quota
-- semantics, §Migrations 0070; the Plus-plan amendment, spec 23 / AMBR-57).
--
-- Wave A: independent of billing. Four decisions land in one re-creation of
-- `claim_ai_call`, because they are the same thirty lines of one function and
-- splitting them would mean two re-creations of one body in one wave.
--
--   1. `import` LEAVES the scans pool and becomes its own monthly pool. The one
--      behavioural change to live semantics here: an AI-arm import used to cost
--      a scan, and now costs an import.
--   2. `shelf_life` gains a monthly pool of 100 beside its own daily 20. Its
--      pool was `null` — uncharged monthly — and one claim buys up to twenty
--      model calls, so only the daily cap bounded the spend (run-costs finding
--      3, AMBR-52).
--   3. The DAILY count becomes per-kind-pool, the shape the monthly side
--      already had. Today it is kind-agnostic (0043:181-183; 0046:507 left it
--      so deliberately), which means `barcode_fetch` — which ADR D1 says must
--      never be metered — spends one of the receipt path's 20: twenty-one
--      unknown barcodes killed receipt scanning for 24 hours, and a day of
--      scans refused a barcode lookup. Everett, 2026-09-13: "that's not a
--      thing." After this, `barcode_fetch`, `import_fetch` and `shelf_life`
--      each count only themselves against the cap their route passes, and the
--      five AI kinds share `QUOTA_DAILY_CAP`.
--   4. `meal_plan` joins `ai_calls_kind_check` and BOTH pool cases (Everett's
--      ruling, 2026-09-13 05:00) — its own monthly pool, the AI kinds' shared
--      daily pool — so the meal-planning spec ships its route without a third
--      re-creation of this function. The fields read 0 until that route exists.
--
-- Plus the 0059 fold: the UTC round trip, never written under its own number.
--
-- SIGNATURE UNCHANGED — (p_user, p_kind, p_free_monthly, p_plus_monthly,
-- p_daily_cap). The limits were always per-call parameters, so the split is in
-- the counting, not the interface, and no caller breaks.
--
-- ORDER (§Migrations 0070 §Order, FIND-001): the Worker PR that makes every
-- route pass the limits this function will read must be MERGED AND DEPLOYED
-- before this migration is applied. `shelfLife.ts` on main passes `0, 0` as
-- shelf-life's monthly limits — inert only while the pool is null, and the
-- kill switch the moment decision 2 gives it a real one.
--
-- No grant change: `claim_ai_call` and `refund_ai_call` keep their
-- service-role-only ACL, as they did through 0042, 0043 and 0046.

-- 1. The kind vocabulary ------------------------------------------------------
--
-- Drop + re-add, the 0005 / 0043 / 0046 convention, with the set read off the
-- CURRENT constraint (0046:516-518) rather than guessed — dropping a kind here
-- would silently break a live route.
--
--   `meal_plan` — a meal-plan generation (the meal-planning spec's route).
alter table public.ai_calls drop constraint ai_calls_kind_check;
alter table public.ai_calls add constraint ai_calls_kind_check
  check (kind in ('receipt', 'photo', 'shelf_life', 'ideas', 'import',
                  'import_fetch', 'barcode_fetch', 'meal_plan'));

-- 2. The function -------------------------------------------------------------
--
-- 0043's body preserved verbatim except where named above: 0027's
-- advisory-locked count-and-insert, 0042's `ideas` bucket, the monthly-before-
-- daily verdict order, and the returned JSON shape are all unchanged.
create or replace function public.claim_ai_call(
  p_user uuid,
  p_kind text,
  p_free_monthly int,
  p_plus_monthly int,
  p_daily_cap int
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  -- THE 0059 FOLD (review G FIND-011, PR #182 round 1 advocate 7).
  -- `now() at time zone 'utc'` yields a TIMESTAMP with no zone; assigning that
  -- to a timestamptz makes Postgres cast it back using the SESSION's TimeZone,
  -- so on a connection that is not UTC the month started hours late for the
  -- ENFORCEMENT half of the meter. The trailing `at time zone 'utc'` is the
  -- return leg of the round trip — the same thing scanQuota.ts (the display
  -- half) has written out since 2026-09-04, said here in SQL rather than left
  -- to `workers/src/db.ts` pinning TimeZone through the pooler.
  v_month_start timestamptz := (date_trunc('month', now() at time zone 'utc')
                                  at time zone 'utc');
  -- …and the display leg stays a PLAIN timestamp, for the reason scanQuota.ts
  -- gives at the same line: `to_char` stamps a literal Z, and the value is
  -- already UTC wall-clock. As a timestamptz it would render in the session
  -- zone and put the wrong instant behind that Z. Under 0043 that error and
  -- the month-start error cancelled; with the start fixed, this one would not.
  v_month_end   timestamp   := date_trunc('month', now() at time zone 'utc')
                                 + interval '1 month';
  v_day_since   timestamptz := now() - interval '24 hours';
  -- The monthly pool this kind is charged against. NULL = uncharged monthly,
  -- which is not the same as an empty pool, and after this migration is true of
  -- the two fetch kinds only.
  v_pool        text[];
  -- The daily pool this kind is counted in. Never null: the abuse cap applies
  -- to every kind, it just no longer applies ACROSS them.
  v_daily_pool  text[];
  v_plan        text;
  v_period_end  timestamptz;
  v_effective   text;
  v_limit       int;
  v_monthly     int := 0;
  v_daily       int;
  v_exhausted   text := null;
  v_id          uuid := null;
begin
  -- BOTH cases enumerate every kind `ai_calls_kind_check` allows and end in a
  -- RAISE rather than 0043's `else null` (FIND-006). That `else` is the whole
  -- reason `shelf_life` went uncharged monthly for four months; with it gone, a
  -- future migration that adds a kind without a pool decision fails its first
  -- claim loudly in rehearsal instead of shipping the next uncharged pool. A
  -- new kind's pool decision is made in that kind's spec and lands in the same
  -- migration as the kind.
  case p_kind
    when 'receipt', 'photo' then v_pool := array['receipt', 'photo'];
    when 'import'           then v_pool := array['import'];
    when 'ideas'            then v_pool := array['ideas'];
    when 'meal_plan'        then v_pool := array['meal_plan'];
    when 'shelf_life'       then v_pool := array['shelf_life'];
    when 'import_fetch', 'barcode_fetch' then v_pool := null;
    else raise exception 'claim_ai_call: no pool for kind %', p_kind;
  end case;

  case p_kind
    when 'receipt', 'photo', 'import', 'ideas', 'meal_plan'
      then v_daily_pool := array['receipt', 'photo', 'import', 'ideas', 'meal_plan'];
    when 'import_fetch'  then v_daily_pool := array['import_fetch'];
    when 'barcode_fetch' then v_daily_pool := array['barcode_fetch'];
    when 'shelf_life'    then v_daily_pool := array['shelf_life'];
    else raise exception 'claim_ai_call: no daily pool for kind %', p_kind;
  end case;

  -- Serialize every quota decision for this user. Transaction-scoped, so it
  -- releases on commit/rollback with no cleanup path to forget.
  perform pg_advisory_xact_lock(pg_catalog.hashtextextended('ai_quota:' || p_user::text, 0));

  select e.plan, e.current_period_end into v_plan, v_period_end
  from public.entitlements e where e.user_id = p_user;

  -- Mirrors _shared/quota.ts effectivePlan: a `plus` row past its period end
  -- demotes to free, so a missed downgrade webhook self-corrects.
  if v_plan is distinct from 'plus' or (v_period_end is not null and v_period_end <= now()) then
    v_effective := 'free';
    v_limit := p_free_monthly;
  else
    v_effective := 'plus';
    v_limit := p_plus_monthly;
  end if;

  if v_pool is not null then
    select count(*) into v_monthly from public.ai_calls c
     where c.user_id = p_user and c.kind = any(v_pool) and c.created_at >= v_month_start;
  end if;

  -- The daily cap is still an abuse cap, not a plan quota — it is the POOL that
  -- narrowed, not the purpose. `p_daily_cap` is whatever this kind's route
  -- passes: QUOTA_DAILY_CAP (20) for the five AI kinds, IMPORT_FETCH_DAILY_CAP
  -- (20), CATALOG_DAILY_CAP (50), SHELF_LIFE_DAILY_CAP (20).
  select count(*) into v_daily from public.ai_calls c
   where c.user_id = p_user and c.kind = any(v_daily_pool) and c.created_at >= v_day_since;

  -- Monthly before daily: a user at both limits should see "upgrade", not
  -- "wait until tomorrow". A kind with no monthly pool is never refused for a
  -- full quota, only for the abuse cap. A limit of 0 is the kill switch and
  -- lands here, as it always has.
  if v_pool is not null and v_monthly >= v_limit then
    v_exhausted := 'monthly';
  elsif v_daily >= p_daily_cap then
    v_exhausted := 'daily';
  else
    insert into public.ai_calls (user_id, kind, item_count)
    values (p_user, p_kind, 0)
    returning id into v_id;
  end if;

  return jsonb_build_object(
    'claim_id', v_id,
    'plan', v_effective,
    'used', v_monthly,
    'limit', v_limit,
    'remaining', greatest(0, v_limit - v_monthly),
    'resets_at', to_char(v_month_end, 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
    'exhausted', v_exhausted
  );
end;
$$;
