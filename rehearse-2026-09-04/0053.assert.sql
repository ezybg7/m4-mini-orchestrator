-- ============================================================================
-- Assertions for migration 0053 (audit 2026-09-04 area D — FIND-004, FIND-013,
-- FIND-014 — plus the same day's two column-scope grants, N12-N15), and N16 pinning audit B9.
--
-- GUI edition, per db/apply/check-0038-gui.sql: it returns ONE ROW instead of
-- RAISE NOTICE output, because the Neon SQL Editor silently discards notices —
-- in a browser a pass and a failure looked identical.
--
-- Run against a NEON BRANCH with the migration applied (specs/MIGRATIONS.md —
-- there is no local database and no runner). Use the DIRECT endpoint (drop
-- `-pooler`; the pooler ignores database-level search_path):
--
--   psql "$NEON_BRANCH_DIRECT_URL" -v ON_ERROR_STOP=1 -1 -f supabase/migrations/0053_merge_integrity.sql
--   psql "$NEON_BRANCH_DIRECT_URL" -f db/asserts/0053_merge_integrity.sql
--
-- or paste this file ALONE into the Neon SQL Editor. You get back:
--
--     result
--     -----------------------------------------
--     ALL 16 ASSERTIONS PASSED
--   or
--     FAILED [errcode]: N3 FAIL: a zone from another location was accepted
--
-- Everything runs inside a transaction this script rolls back itself, so it is
-- safe to re-run and leaves no rows behind.
--
-- ----------------------------------------------------------------------------
-- IDENTITY (FIND-009). Eight of these sixteen call `merge_add_items` or
-- `add_grocery_items`, both of which gate on `is_household_member` ⇒
-- `auth.uid()`. On Neon that is pg_session_jwt's C
-- function, not Supabase's SQL one, and db/asserts/0038_sweep_adds_to_list.sql
-- has been unrunnable since the cutover because it fakes identity with
-- `set_config('request.jwt.claim.sub', …)` — the LEGACY SCALAR GUC, which
-- pg_session_jwt does not read at all.
--
-- What it does read, when no JWK is configured for the session, is the
-- PostgREST-compatible **`request.jwt.claims`** object GUC (the extension's
-- documented fallback: `auth.session()`/`auth.user_id()`/`auth.uid()` consult
-- it whenever `pg_session_jwt.jwk` is unset, which is the case for every plain
-- psql session — the JWK can only be supplied in the connection startup packet,
-- e.g. `PGOPTIONS="-c pg_session_jwt.jwk=$JWK"`). So the fix for 0038 is very
-- probably one GUC name, not a real signed token.
--
-- This file does not assume that. It SETS the claims GUC, then checks whether
-- `auth.uid()` actually came back, and says which of the two it got:
--
--     ALL 16 ASSERTIONS PASSED
--     PASSED 8 OF 16 — 8 BEHAVIOURAL SKIPPED (auth.uid() did not resolve …)
--
-- The second string is a result, not a pass: it names the gap out loud instead
-- of going quietly green, and it is what tells the operator to fall back to a
-- real token — sign in as the acceptance account, mint a Data-API JWT
-- (`/auth/token`), reconnect with `PGOPTIONS="-c pg_session_jwt.jwk=<the
-- Worker's JWKS key>"` and call `auth.jwt_session_init('<jwt>')` before this
-- file. Whichever path works, record it in specs/MIGRATIONS.md so 0038 can be
-- fixed the same way.
--
-- The other eight need no identity at all: the placement trigger fires on plain
-- inserts, and the grant/shape pins read the catalogs.
-- ============================================================================

begin;

create function pg_temp.check_0053() returns text language plpgsql as $fn$
declare
  v_user     uuid;
  v_hh       uuid;
  v_loc_a    uuid;
  v_loc_b    uuid;
  v_loc_cap  uuid;
  v_loc_bat  uuid;
  v_far_hh   uuid;
  v_far_loc  uuid;
  v_zone_a   uuid;
  v_zone_b   uuid;
  v_item     uuid;
  v_cat      uuid;
  v_n        int;
  v_def      text;
  v_cat_got  public.food_category;
  v_link     uuid;
  v_exp      date;
  v_other    uuid;
  v_role     text;
  v_col      text;
  v_ok       boolean;
  v_identity boolean;
  v_payload  jsonb;
begin
  -- ==========================================================================
  -- Seed. `app_auth."user"` is the root of the FK chain and plainly insertable
  -- (the 0049/0050 technique); its trigger writes the profile.
  -- ==========================================================================
  insert into app_auth."user" (name, email, "emailVerified", "updatedAt")
  values ('Assert 0053', 'assert-0053@ambry.invalid', false, now())
  returning id into v_user;

  insert into public.households (name, created_by) values ('0053 assert home', v_user)
  returning id into v_hh;
  insert into public.household_members (household_id, user_id, role)
  values (v_hh, v_user, 'owner');

  insert into public.storage_locations (household_id, name, kind)
  values (v_hh, '0053 Pantry A', 'pantry') returning id into v_loc_a;
  insert into public.storage_locations (household_id, name, kind)
  values (v_hh, '0053 Pantry B', 'pantry') returning id into v_loc_b;
  insert into public.storage_locations (household_id, name, kind)
  values (v_hh, '0053 Pantry Cap', 'pantry') returning id into v_loc_cap;
  insert into public.storage_locations (household_id, name, kind)
  values (v_hh, '0053 Pantry Batch', 'pantry') returning id into v_loc_bat;

  insert into public.zones (location_id, name) values (v_loc_a, '0053 Top shelf')
  returning id into v_zone_a;
  insert into public.zones (location_id, name) values (v_loc_b, '0053 Door')
  returning id into v_zone_b;

  -- A second household with its own location, for the 0028 clause N4 re-pins.
  insert into public.households (name) values ('0053 assert other home')
  returning id into v_far_hh;
  insert into public.storage_locations (household_id, name, kind)
  values (v_far_hh, '0053 Elsewhere', 'pantry') returning id into v_far_loc;

  -- The catalog spice both FIND-004 orderings converge on. The free-text adds
  -- below differ only in case, which `normalize_item_name` folds away.
  insert into public.catalog_items (name, category)
  values ('Assert Cumin 0053', 'spices') returning id into v_cat;

  -- ==========================================================================
  -- N1. The placement trigger watches zone_id.
  --
  -- The load-bearing half of FIND-014 is not the new clause, it is the COLUMN
  -- LIST: pinning an item is a bare `PATCH {zone_id}`, which touches neither
  -- location_id nor household_id, so 0028's trigger never fired on the one
  -- statement the app actually uses to pin. A clause on an unwatched column is
  -- decoration.
  -- ==========================================================================
  select count(*) into v_n
    from pg_trigger t
    join pg_proc p on p.oid = t.tgfoid
    join pg_attribute a
      on a.attrelid = t.tgrelid
     and a.attname in ('location_id', 'household_id', 'zone_id')
     -- `tgattr` is an int2vector; its text form is space-separated attnums.
     -- Compared as TEXT rather than cast to smallint[] so an empty column list
     -- (which renders as '') reports 0 matches instead of raising 22P02.
     and a.attnum::text = any (string_to_array(t.tgattr::text, ' '))
   where t.tgrelid = 'public.inventory_items'::regclass
     and t.tgname = 'inventory_items_location_scope'
     and not t.tgisinternal
     and p.proname = 'assert_item_location_scope'
     -- ROW(1) + BEFORE(2) + INSERT(4) + UPDATE(16). A trigger that became AFTER
     -- would let the bad row land before raising.
     and t.tgtype = 23;
  if v_n <> 3 then
    raise exception 'N1 FAIL: the scope trigger watches % of location_id/household_id/zone_id (want 3, BEFORE INSERT OR UPDATE ROW)', v_n;
  end if;
  raise notice 'N1 ok: BEFORE INSERT OR UPDATE OF location_id, household_id, zone_id';

  -- ==========================================================================
  -- N2. A zone under ANOTHER location is refused — on INSERT and on UPDATE.
  -- The update half is the real-world one: the pin PATCH.
  -- ==========================================================================
  begin
    insert into public.inventory_items (household_id, location_id, zone_id, name_override, category)
    values (v_hh, v_loc_a, v_zone_b, 'Cross-pinned on insert', 'other');
    raise exception 'N2 FAIL: an insert pinned a zone from another location';
  exception when check_violation then null;
  end;

  insert into public.inventory_items (household_id, location_id, name_override, category)
  values (v_hh, v_loc_a, 'Pin probe', 'other') returning id into v_item;
  begin
    update public.inventory_items set zone_id = v_zone_b where id = v_item;
    raise exception 'N2 FAIL: a PATCH pinned a zone from another location';
  exception when check_violation then null;
  end;
  raise notice 'N2 ok: a zone under another location is refused on insert and on update';

  -- ==========================================================================
  -- N3. The item's OWN location's zone is accepted, and unpinning still works.
  -- A check that only ever refuses would pass while breaking the feature.
  -- ==========================================================================
  update public.inventory_items set zone_id = v_zone_a where id = v_item;
  select zone_id into v_link from public.inventory_items where id = v_item;
  if v_link is distinct from v_zone_a then
    raise exception 'N3 FAIL: a zone under the item''s own location did not stick';
  end if;
  update public.inventory_items set zone_id = null where id = v_item;
  insert into public.inventory_items (household_id, location_id, zone_id, name_override, category)
  values (v_hh, v_loc_a, v_zone_a, 'Pinned on insert', 'other');
  raise notice 'N3 ok: the item''s own zone is accepted, and null still unpins';

  -- ==========================================================================
  -- N4. 0028's clause is untouched: a location from another household is still
  -- refused, and a move that carries a stale zone is caught by the new clause.
  -- ==========================================================================
  begin
    insert into public.inventory_items (household_id, location_id, name_override, category)
    values (v_hh, v_far_loc, 'Wrong household', 'other');
    raise exception 'N4 FAIL: a location from another household was accepted';
  exception when check_violation then null;
  end;
  begin
    -- v_item sits in loc_a; moving it to loc_b while keeping loc_a's zone is
    -- exactly the mismatch `useMoveItems` avoids by nulling zone_id.
    update public.inventory_items set location_id = v_loc_b, zone_id = v_zone_a where id = v_item;
    raise exception 'N4 FAIL: a move carried a zone from the old location';
  exception when check_violation then null;
  end;
  raise notice 'N4 ok: 0028''s household clause holds, and a stale zone survives no move';

  -- ==========================================================================
  -- N5. merge_add_items is still SECURITY INVOKER with the 0014 grants. Both
  -- halves matter after a `create or replace`: the posture is what keeps RLS
  -- the authority, and PUBLIC EXECUTE is the default this file has to deny.
  -- ==========================================================================
  select prosecdef into v_ok from pg_proc
   where oid = 'public.merge_add_items(uuid,jsonb)'::regprocedure;
  if v_ok then
    raise exception 'N5 FAIL: merge_add_items came back SECURITY DEFINER';
  end if;
  if not has_function_privilege('authenticated', 'public.merge_add_items(uuid,jsonb)', 'execute') then
    raise exception 'N5 FAIL: authenticated cannot execute merge_add_items';
  end if;
  -- A NULL proacl is the DEFAULT acl, which grants EXECUTE to PUBLIC — and it
  -- explodes to zero rows, so the check below would pass on the one state it
  -- most needs to catch.
  select count(*) into v_n
    from pg_proc p
   where p.oid = 'public.merge_add_items(uuid,jsonb)'::regprocedure and p.proacl is null;
  if v_n > 0 then
    raise exception 'N5 FAIL: merge_add_items carries default privileges (PUBLIC EXECUTE)';
  end if;
  -- grantee 0 is PUBLIC in an exploded ACL; has_function_privilege('public', …)
  -- would look for a ROLE called public and error.
  select count(*) into v_n
    from pg_proc p, aclexplode(p.proacl) a
   where p.oid = 'public.merge_add_items(uuid,jsonb)'::regprocedure and a.grantee = 0;
  if v_n > 0 then
    raise exception 'N5 FAIL: PUBLIC holds % privileges on merge_add_items', v_n;
  end if;
  for v_role in select rolname from pg_roles where rolname in ('anon', 'anonymous') loop
    if has_function_privilege(v_role, 'public.merge_add_items(uuid,jsonb)', 'execute') then
      raise exception 'N5 FAIL: % can execute merge_add_items', v_role;
    end if;
  end loop;
  raise notice 'N5 ok: INVOKER, authenticated-only, nothing to PUBLIC or the anonymous role';

  -- ==========================================================================
  -- N6. The cap is raised BEFORE the advisory lock (FIND-013).
  --
  -- N9 proves the cap refuses; only the deployed definition can prove the
  -- ORDER, which is the property that matters — a caller who is refused must
  -- never have been able to take `inventory_merge:<household>` first (0038's
  -- membership-before-lock reasoning). Text-matched on purpose, the 0040 B10
  -- and 0052 M11 technique: an edit that moves the check below the lock keeps
  -- every behavioural assertion green and loses the property.
  -- ==========================================================================
  select pg_get_functiondef('public.merge_add_items(uuid,jsonb)'::regprocedure) into v_def;
  if position('jsonb_array_length(p_items) > 200' in v_def) = 0 then
    raise exception 'N6 FAIL: merge_add_items does not cap p_items at 200';
  end if;
  -- The SQLSTATE is contract, not detail: the client's copy for this refusal
  -- keys off it, and `check_violation` would be indistinguishable from the
  -- placement trigger or any column CHECK.
  if position('AMB01' in v_def) = 0 then
    raise exception 'N6 FAIL: the cap no longer raises the dedicated AMB01 code';
  end if;
  if position('jsonb_array_length(p_items)' in v_def)
     > position('pg_advisory_xact_lock' in v_def) then
    raise exception 'N6 FAIL: the p_items cap is raised AFTER the advisory lock';
  end if;
  if position('is_household_member' in v_def)
     > position('jsonb_array_length(p_items)' in v_def) then
    raise exception 'N6 FAIL: the membership check no longer precedes the cap';
  end if;
  raise notice 'N6 ok: membership, then the 200-item cap, then the lock';

  -- ==========================================================================
  -- N12. `households` UPDATE is column-scoped (grants review 2026-09-04).
  --
  -- `has_table_privilege` is TRUE only for a TABLE-level grant; a column-level
  -- one shows up in `has_column_privilege` alone. That asymmetry is what lets
  -- these two lines say "no blanket UPDATE, yes these four columns" — the 0050
  -- K-suite technique, for the same reason: a policy scopes rows and never
  -- columns, so the grant is the only thing standing between an owner and
  -- `created_by`.
  -- ==========================================================================
  if has_table_privilege('authenticated', 'public.households', 'update') then
    raise exception 'N12 FAIL: authenticated still holds table-level UPDATE on households';
  end if;
  if has_table_privilege('authenticated', 'public.households', 'insert') then
    raise exception 'N12 FAIL: authenticated holds INSERT on households (0046 revoked it)';
  end if;
  if not has_table_privilege('authenticated', 'public.households', 'select') then
    raise exception 'N12 FAIL: the revoke took SELECT with it';
  end if;
  foreach v_col in array array['name', 'invite_code', 'auto_clear_out_days', 'auto_add_out_to_list'] loop
    if not has_column_privilege('authenticated', 'public.households', v_col, 'update') then
      raise exception 'N12 FAIL: the client cannot update households.%', v_col;
    end if;
  end loop;
  -- `created_by` is the client's home-household key; `id` and `created_at` are
  -- identity. None of the three is ever written by the app.
  foreach v_col in array array['id', 'created_by', 'created_at'] loop
    if has_column_privilege('authenticated', 'public.households', v_col, 'update') then
      raise exception 'N12 FAIL: authenticated can still write households.%', v_col;
    end if;
  end loop;
  raise notice 'N12 ok: households UPDATE is the four client columns, and created_by is not one';

  -- ==========================================================================
  -- N13. `grocery_items` INSERT is gone and UPDATE is (status, category).
  --
  -- The byline is the point: with table-wide UPDATE, a bare `PATCH {added_by}`
  -- walked around the membership check 0046 put inside `add_grocery_items`,
  -- and the list renders that column as a person's name. N14/N15 below run the
  -- RPC's own check; this pins the door the RPC is now the only way through.
  -- ==========================================================================
  if has_table_privilege('authenticated', 'public.grocery_items', 'insert') then
    raise exception 'N13 FAIL: authenticated can bare-insert grocery rows (add_grocery_items is the only path)';
  end if;
  if has_table_privilege('authenticated', 'public.grocery_items', 'update') then
    raise exception 'N13 FAIL: authenticated still holds table-level UPDATE on grocery_items';
  end if;
  -- SELECT and DELETE are whole-row operations the policy CAN scope, and the
  -- list screen needs both (deleteGroceryItem / clearCheckedGrocery).
  if not has_table_privilege('authenticated', 'public.grocery_items', 'select')
     or not has_table_privilege('authenticated', 'public.grocery_items', 'delete') then
    raise exception 'N13 FAIL: the revoke took SELECT or DELETE with it';
  end if;
  foreach v_col in array array['status', 'category'] loop
    if not has_column_privilege('authenticated', 'public.grocery_items', v_col, 'update') then
      raise exception 'N13 FAIL: the client cannot update grocery_items.%', v_col;
    end if;
  end loop;
  foreach v_col in array array['added_by', 'name', 'household_id', 'catalog_item_id', 'checked_at'] loop
    if has_column_privilege('authenticated', 'public.grocery_items', v_col, 'update') then
      raise exception 'N13 FAIL: authenticated can still write grocery_items.%', v_col;
    end if;
  end loop;
  raise notice 'N13 ok: grocery_items is select/delete + update(status, category) only';

  -- ==========================================================================
  -- Identity for the five behavioural assertions. See the header: the object
  -- GUC, not 0038's legacy scalar one.
  -- ==========================================================================
  begin
    perform set_config('request.jwt.claims', json_build_object('sub', v_user::text)::text, true);
    v_identity := coalesce(auth.uid() = v_user, false);
  exception when others then
    v_identity := false;
  end;

  if v_identity then
    -- ========================================================================
    -- N7. FIND-004, ordering ONE: free-text first, then the catalog spice.
    -- 0019 merged these (the incoming row was the spice) but never rewrote the
    -- stored category, so the row kept 'other' while holding a spice's catalog
    -- link.
    -- ========================================================================
    perform public.merge_add_items(v_hh, jsonb_build_array(jsonb_build_object(
      'location_id', v_loc_a, 'catalog_item_id', null,
      'name_override', 'assert cumin 0053', 'category', 'other',
      'expires_at', null, 'expiry_source', null)));
    perform public.merge_add_items(v_hh, jsonb_build_array(jsonb_build_object(
      'location_id', v_loc_a, 'catalog_item_id', v_cat,
      'name_override', null, 'category', 'spices',
      'expires_at', '2027-01-01', 'expiry_source', 'shelf_life')));

    -- Counted through the RPC's own identity expression, so this asks the same
    -- question the merge asked rather than a lookalike.
    select count(*) into v_n
      from public.inventory_items i
      left join public.catalog_items c on c.id = i.catalog_item_id
     where i.household_id = v_hh and i.location_id = v_loc_a
       and public.normalize_item_name(coalesce(i.name_override, c.name, ''))
           = public.normalize_item_name('Assert Cumin 0053');
    if v_n <> 1 then
      raise exception 'N7 FAIL: free-text then catalog left % rows, expected 1', v_n;
    end if;
    select i.category, i.catalog_item_id, i.expires_at into v_cat_got, v_link, v_exp
      from public.inventory_items i
     where i.household_id = v_hh and i.location_id = v_loc_a and i.catalog_item_id = v_cat;
    if v_cat_got <> 'spices' then
      raise exception 'N7 FAIL: the merged row is categorised %, expected spices', v_cat_got;
    end if;
    if v_link is distinct from v_cat then
      raise exception 'N7 FAIL: the catalog link was not backfilled';
    end if;
    if v_exp is distinct from date '2027-01-01' then
      raise exception 'N7 FAIL: the spice re-add did not refresh the expiry (new jar, new clock)';
    end if;
    raise notice 'N7 ok: free-text then catalog = one row, spices, linked, clock refreshed';

    -- ========================================================================
    -- N8. FIND-004, ordering TWO: the catalog spice first, then a free-text
    -- re-add. 0019 read only the incoming 'other', demanded an equal expiry
    -- against the catalog row's shelf-life date, and inserted a SECOND row.
    --
    -- B9's "new jar, new clock" still applies whenever the incoming add HAS a
    -- date; a dateless one now leaves the stored date alone (lead call
    -- 2026-09-04, recorded in the migration header). N16 below covers the other
    -- direction, so neither half can be dropped without a failure.
    -- ========================================================================
    perform public.merge_add_items(v_hh, jsonb_build_array(jsonb_build_object(
      'location_id', v_loc_b, 'catalog_item_id', v_cat,
      'name_override', null, 'category', 'spices',
      'expires_at', '2027-01-01', 'expiry_source', 'shelf_life')));
    perform public.merge_add_items(v_hh, jsonb_build_array(jsonb_build_object(
      'location_id', v_loc_b, 'catalog_item_id', null,
      'name_override', 'ASSERT CUMIN 0053', 'category', 'other',
      'expires_at', null, 'expiry_source', null)));

    select count(*) into v_n from public.inventory_items i
     where i.household_id = v_hh and i.location_id = v_loc_b;
    if v_n <> 1 then
      raise exception 'N8 FAIL: catalog then free-text left % rows, expected 1', v_n;
    end if;
    select i.category, i.catalog_item_id, i.expires_at into v_cat_got, v_link, v_exp
      from public.inventory_items i
     where i.household_id = v_hh and i.location_id = v_loc_b;
    if v_cat_got <> 'spices' then
      raise exception 'N8 FAIL: a free-text re-add re-categorised the spice to %', v_cat_got;
    end if;
    if v_link is distinct from v_cat then
      raise exception 'N8 FAIL: a free-text re-add dropped the catalog link';
    end if;
    -- THE DATE SURVIVES. This is the assertion that would have caught the
    -- original 0053 draft, which wrote `else rec.expires_at` literally and so
    -- cleared the only copy of the date on a re-add the user experiences as
    -- "I bought more cumin". Under 0019 the same write was survivable because
    -- the two rows did not merge; merging them is what made it destructive.
    if v_exp is distinct from date '2027-01-01' then
      raise exception 'N8 FAIL: the dateless re-add wiped the stored date (now %) — a payload with no date is an absence of information, not a claim the jar has none', v_exp;
    end if;
    raise notice 'N8 ok: catalog then free-text = one row, still spices, still linked, date kept';

    -- ========================================================================
    -- N16. The other direction: a spice re-add that DOES carry a date still
    -- refreshes the clock (audit B9, "new jar, new clock"). N8 alone would pass
    -- on a body that simply never overwrote the date, which would quietly
    -- retire B9 -- the rule that a re-bought jar starts its shelf life again.
    -- The two together pin the actual rule: the incoming date wins when there
    -- IS one, and only then.
    -- ========================================================================
    perform public.merge_add_items(v_hh, jsonb_build_array(jsonb_build_object(
      'location_id', v_loc_b, 'catalog_item_id', v_cat,
      'name_override', null, 'category', 'spices',
      'expires_at', '2027-06-30', 'expiry_source', 'shelf_life')));
    select i.expires_at into v_exp from public.inventory_items i
     where i.household_id = v_hh and i.location_id = v_loc_b;
    if v_exp is distinct from date '2027-06-30' then
      raise exception 'N16 FAIL: a DATED spice re-add did not refresh the clock (still %) — B9 is gone', v_exp;
    end if;
    select count(*) into v_n from public.inventory_items
     where household_id = v_hh and location_id = v_loc_b;
    if v_n <> 1 then
      raise exception 'N16 FAIL: the dated re-add made a second row (% total)', v_n;
    end if;
    raise notice 'N16 ok: a dated spice re-add still refreshes the clock, still one row';

    -- ========================================================================
    -- N9. FIND-013: 201 items are refused, 200 are accepted. The refusal must
    -- carry the dedicated AMB01 SQLSTATE -- not `check_violation`, which the
    -- placement trigger and every column CHECK also raise, and not a bare
    -- P0001, which is what "not a member of this household" is. The client's
    -- specific copy for this case keys off exactly this code.
    -- ========================================================================
    select jsonb_agg(jsonb_build_object(
             'location_id', v_loc_cap, 'catalog_item_id', null,
             'name_override', 'Cap probe ' || g, 'category', 'other',
             'expires_at', null, 'expiry_source', null))
      into v_payload
      from generate_series(1, 201) g;
    begin
      perform public.merge_add_items(v_hh, v_payload);
      raise exception 'N9 FAIL: 201 items were accepted';
    exception
      when sqlstate 'AMB01' then null;
      when check_violation then
        raise exception 'N9 FAIL: the cap raised check_violation, not AMB01 — '
          'the client cannot tell it from a constraint or a scope refusal';
    end;

    select jsonb_agg(jsonb_build_object(
             'location_id', v_loc_cap, 'catalog_item_id', null,
             'name_override', 'Cap probe ' || g, 'category', 'other',
             'expires_at', null, 'expiry_source', null))
      into v_payload
      from generate_series(1, 200) g;
    if public.merge_add_items(v_hh, v_payload) <> 200 then
      raise exception 'N9 FAIL: a full-size 200-item payload was not accepted whole';
    end if;
    raise notice 'N9 ok: 201 raises AMB01, 200 commits';

    -- ========================================================================
    -- N10. Batching is untouched. The spice branch is the exception, not the
    -- rule, and a fix that quietly made everything dedupe on name would pass
    -- N7 and N8 while collapsing every expiry cohort in the pantry.
    -- ========================================================================
    perform public.merge_add_items(v_hh, jsonb_build_array(jsonb_build_object(
      'location_id', v_loc_bat, 'catalog_item_id', null,
      'name_override', 'Assert Milk 0053', 'category', 'dairy_eggs',
      'expires_at', '2027-02-01', 'expiry_source', 'shelf_life')));
    perform public.merge_add_items(v_hh, jsonb_build_array(jsonb_build_object(
      'location_id', v_loc_bat, 'catalog_item_id', null,
      'name_override', 'Assert Milk 0053', 'category', 'dairy_eggs',
      'expires_at', '2027-02-05', 'expiry_source', 'shelf_life')));
    select count(*) into v_n from public.inventory_items
     where household_id = v_hh and location_id = v_loc_bat;
    if v_n <> 2 then
      raise exception 'N10 FAIL: two expiry cohorts collapsed into % row(s)', v_n;
    end if;
    perform public.merge_add_items(v_hh, jsonb_build_array(jsonb_build_object(
      'location_id', v_loc_bat, 'catalog_item_id', null,
      'name_override', 'Assert Milk 0053', 'category', 'dairy_eggs',
      'expires_at', '2027-02-01', 'expiry_source', 'shelf_life')));
    select count(*) into v_n from public.inventory_items
     where household_id = v_hh and location_id = v_loc_bat;
    if v_n <> 2 then
      raise exception 'N10 FAIL: a same-date re-add made a third row';
    end if;
    raise notice 'N10 ok: different expiry still batches, same expiry still merges';

    -- ========================================================================
    -- N11. The stored-category probe is LOCATION-SCOPED. Spice rows for this
    -- exact name now exist in loc_a and loc_b; two non-spice adds of the SAME
    -- name into a THIRD location must still open two expiry cohorts. A probe
    -- that forgot `location_id` would read those other rows as "this is a
    -- spice", dedupe on name alone, and silently widen the merge identity the
    -- whole spec is built on — while every other assertion here stayed green.
    -- ========================================================================
    perform public.merge_add_items(v_hh, jsonb_build_array(jsonb_build_object(
      'location_id', v_loc_bat, 'catalog_item_id', null,
      'name_override', 'assert cumin 0053', 'category', 'other',
      'expires_at', '2027-03-01', 'expiry_source', 'shelf_life')));
    perform public.merge_add_items(v_hh, jsonb_build_array(jsonb_build_object(
      'location_id', v_loc_bat, 'catalog_item_id', null,
      'name_override', 'assert cumin 0053', 'category', 'other',
      'expires_at', '2027-03-09', 'expiry_source', 'shelf_life')));
    select count(*) into v_n from public.inventory_items
     where household_id = v_hh and location_id = v_loc_bat
       and name_override = 'assert cumin 0053';
    if v_n <> 2 then
      raise exception 'N11 FAIL: % row(s) for two cohorts — a spice in ANOTHER location reached this one', v_n;
    end if;
    raise notice 'N11 ok: a spice in one location does not reach another';

    -- ========================================================================
    -- N14. The grocery byline cannot be forged through the RPC either.
    --
    -- 0046's SCH-08/SEC-15 check is what N13's revoke leaves as the ONLY way to
    -- set `added_by`, so the two are a pair and this is the half that needs
    -- identity. db/asserts/0046 pins it by string-matching `prosrc`; this runs
    -- it. A stranger's id must be silently replaced by the caller — not stored,
    -- and not raised over (0046: "a wrong byline is not worth failing an add").
    -- ========================================================================
    insert into app_auth."user" (name, email, "emailVerified", "updatedAt")
    values ('Assert 0053 stranger', 'assert-0053-stranger@ambry.invalid', false, now())
    returning id into v_other;

    perform public.add_grocery_items(v_hh, jsonb_build_array(jsonb_build_object(
      'name', 'Assert Byline 0053', 'category', 'other',
      'status', 'needed', 'added_by', v_other)));
    select added_by into v_link from public.grocery_items
     where household_id = v_hh and name = 'Assert Byline 0053';
    if v_link is distinct from v_user then
      raise exception 'N14 FAIL: added_by came back % — a non-member byline was stored', v_link;
    end if;
    raise notice 'N14 ok: a non-member added_by falls back to the caller';

    -- ========================================================================
    -- N15. And a member's OWN byline still round-trips. N14 alone would pass on
    -- a function that ignored `added_by` outright, which would break the one
    -- case the parameter exists for (undo re-adding a row on behalf of whoever
    -- originally added it).
    -- ========================================================================
    insert into public.household_members (household_id, user_id, role)
    values (v_hh, v_other, 'member');
    perform public.add_grocery_items(v_hh, jsonb_build_array(jsonb_build_object(
      'name', 'Assert Byline 0053 b', 'category', 'other',
      'status', 'needed', 'added_by', v_other)));
    select added_by into v_link from public.grocery_items
     where household_id = v_hh and name = 'Assert Byline 0053 b';
    if v_link is distinct from v_other then
      raise exception 'N15 FAIL: a real member''s byline was overwritten';
    end if;
    raise notice 'N15 ok: a member''s own byline is honoured';

    return 'ALL 16 ASSERTIONS PASSED';
  end if;

  return 'PASSED 8 OF 16 — 8 BEHAVIOURAL SKIPPED (auth.uid() did not resolve from '
      || 'request.jwt.claims; supply a real token per this file''s header, then re-run)';
exception
  when others then
    return 'FAILED [' || sqlstate || ']: ' || sqlerrm;
end
$fn$;

select pg_temp.check_0053() as result;

rollback;
