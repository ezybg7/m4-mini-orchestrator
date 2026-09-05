-- ============================================================================
-- Assertions for migration 0047 (specs/catalog-nutrition-matching.md, spec 45).
--
-- GUI edition, per db/asserts/0050_recipe_ratings.sql: returns ONE ROW rather
-- than notices. Run against a NEON BRANCH with the migration applied:
--
--   psql "$NEON_BRANCH_DIRECT_URL" -f supabase/migrations/0047_usda_foods.sql
--   psql "$NEON_BRANCH_DIRECT_URL" -f db/asserts/0047_usda_foods.sql
--
--     result
--     -----------------------------------------
--     ALL 7 ASSERTIONS PASSED
--   or
--     FAILED [errcode]: U2 FAIL: usda_foods has 1 policies, expected exactly 0
--
-- Everything runs inside a transaction this script rolls back itself; safe to
-- re-run, and safe to run BEFORE the seed apply — every row it needs it inserts.
--
-- BEHAVIOURAL where behaviour is the claim (U1's three CHECKs are proven by
-- watching the insert be refused, U4's idempotency by upserting twice, U6 by
-- reading the number back out of jsonb), CATALOG-BASED where the claim is about
-- privilege (U2, U3, U5) — `has_table_privilege` answers for any role, folds
-- table-level grants in, and unlike information_schema does not come back
-- vacuously empty on a database whose owner is not a member of `authenticated`.
--
-- U5 is here rather than in a catalog_items assert file on purpose: spec 45 adds
-- a SECOND writer of `catalog_items.nutrition`, and the security boundary its
-- §Acceptance names is that doing so did not reopen client writes to the global
-- catalog (ADR catalog D5, migration 0046's SCH-07 revoke).
-- ============================================================================

begin;

create function pg_temp.check_0047() returns text language plpgsql as $fn$
declare
  v_n        int;
  v_txt      text;
  v_role     text;
  v_priv     text;
  v_kcal     numeric;
  v_desc     text;
  v_imported timestamptz;
begin
  -- U1. The five columns with the types and nullability the spec names, the
  -- primary key on fdc_id, and all three CHECKs proven by REFUSAL rather than by
  -- reading pg_constraint — a constraint that exists and does not fire is the
  -- failure mode worth catching.
  select count(*) into v_n from information_schema.columns
   where table_schema = 'public' and table_name = 'usda_foods'
     and (
       (column_name = 'fdc_id'      and is_nullable = 'NO' and data_type = 'integer') or
       (column_name = 'description' and is_nullable = 'NO' and data_type = 'text') or
       (column_name = 'data_type'   and is_nullable = 'NO' and data_type = 'text') or
       (column_name = 'nutrition'   and is_nullable = 'NO' and data_type = 'jsonb') or
       (column_name = 'imported_at' and is_nullable = 'NO'
                                    and data_type = 'timestamp with time zone')
     );
  if v_n <> 5 then
    raise exception 'U1 FAIL: usda_foods has % of the 5 specced columns', v_n;
  end if;

  -- Single-column, and that column is fdc_id: a composite PK would still be "a
  -- primary key" while quietly breaking the `on conflict (fdc_id)` upsert the
  -- seed file depends on.
  select count(*) into v_n
    from pg_constraint c
    join pg_attribute a
      on a.attrelid = c.conrelid and a.attnum = any (c.conkey)
   where c.conrelid = 'public.usda_foods'::regclass
     and c.contype = 'p'
     and array_length(c.conkey, 1) = 1
     and a.attname = 'fdc_id';
  if v_n <> 1 then
    raise exception 'U1 FAIL: fdc_id is not the single-column primary key';
  end if;

  -- A real row first: everything below needs one, and inserting it proves the
  -- happy path before any of the refusals mean anything.
  insert into public.usda_foods (fdc_id, description, data_type, nutrition)
  values (999000001, 'Oats, whole grain, rolled', 'sr_legacy',
          '{"kcal": 379.0, "protein_g": 13.2, "salt_g": 0.01}'::jsonb);

  -- A dataset name FDC does not have. Branded foods are a real dataset and a
  -- deliberate omission (spec §Out of scope), so this CHECK is what makes adding
  -- one a migration instead of an insert.
  begin
    insert into public.usda_foods (fdc_id, description, data_type, nutrition)
    values (999000002, 'Branded thing', 'branded_food', '{"kcal": 1.0}'::jsonb);
    raise exception 'U1 FAIL: data_type accepted ''branded_food''';
  exception when check_violation then null;
  end;

  -- A panel that is not an object. The Worker copies this value straight into
  -- `catalog_items.nutrition`, so a bare number here becomes a broken label
  -- there rather than an error anyone sees.
  begin
    insert into public.usda_foods (fdc_id, description, data_type, nutrition)
    values (999000003, 'Scalar panel', 'foundation', '379'::jsonb);
    raise exception 'U1 FAIL: nutrition accepted a bare number';
  exception when check_violation then null;
  end;
  begin
    insert into public.usda_foods (fdc_id, description, data_type, nutrition)
    values (999000004, 'Array panel', 'foundation', '[{"kcal": 1.0}]'::jsonb);
    raise exception 'U1 FAIL: nutrition accepted an array';
  exception when check_violation then null;
  end;

  -- The case `jsonb_typeof(...) = 'object'` alone does NOT catch, and the worse
  -- one: `{}` is an object. Copied onto catalog_items it becomes a non-null
  -- blank panel that the fill path's `nutrition is null` guard can never
  -- revisit — a broken card, permanently, instead of the no-info placeholder.
  begin
    insert into public.usda_foods (fdc_id, description, data_type, nutrition)
    values (999000007, 'Empty panel', 'foundation', '{}'::jsonb);
    raise exception 'U1 FAIL: nutrition accepted an empty object';
  exception when check_violation then null;
  end;

  -- 301 characters: one over the cap the generator truncates to. The cap is the
  -- contract between export-usda-foods.py and this table, so a generator that
  -- stopped truncating must fail the apply, not silently store a 4 KB string.
  begin
    insert into public.usda_foods (fdc_id, description, data_type, nutrition)
    values (999000005, repeat('x', 301), 'foundation', '{"kcal": 1.0}'::jsonb);
    raise exception 'U1 FAIL: a 301-character description was accepted';
  exception when check_violation then null;
  end;
  -- ...and exactly 300 is fine, so the cap is off-by-none.
  insert into public.usda_foods (fdc_id, description, data_type, nutrition)
  values (999000006, repeat('x', 300), 'foundation', '{"kcal": 1.0}'::jsonb);

  -- U2. RLS enabled, and ZERO policies — the `push_tickets` posture. "Zero" is
  -- an invariant, not a list: any policy at all here would mean some non-owner
  -- role can reach FDC data through the Data API.
  select count(*) into v_n from pg_class
   where relname = 'usda_foods' and relnamespace = 'public'::regnamespace
     and relrowsecurity;
  if v_n <> 1 then
    raise exception 'U2 FAIL: RLS is not enabled on usda_foods';
  end if;
  select count(*) into v_n from pg_policies
   where schemaname = 'public' and tablename = 'usda_foods';
  if v_n <> 0 then
    raise exception 'U2 FAIL: usda_foods has % policies, expected exactly 0', v_n;
  end if;

  -- U3. Not one privilege for any client role, on any command — RLS with no
  -- policies already closes the table, but a grant would still be a lie in the
  -- catalog and would open it the moment someone added a policy "to debug". Both
  -- unauthenticated role names are checked because the schema is portable
  -- (Supabase `anon`, Neon `anonymous`); a role that does not exist is skipped
  -- rather than assumed absent.
  foreach v_role in array array['authenticated', 'anon', 'anonymous'] loop
    if not exists (select 1 from pg_roles where rolname = v_role) then
      continue;
    end if;
    foreach v_priv in array array['select', 'insert', 'update', 'delete',
                                  'truncate', 'references', 'trigger'] loop
      if has_table_privilege(v_role, 'public.usda_foods', v_priv) then
        raise exception 'U3 FAIL: % holds % on usda_foods', v_role, v_priv;
      end if;
    end loop;
  end loop;

  -- ...and the other half of the claim, which "no role holds anything" does not
  -- make on its own: the table's OWNER can still read it. That is the Worker's
  -- connection (NEON_DATABASE_URL), and a posture that locked everyone out
  -- including the intended reader would pass every assertion above.
  if not has_table_privilege(current_user, 'public.usda_foods', 'select') then
    raise exception 'U3 FAIL: the owner cannot SELECT usda_foods — nothing can read it';
  end if;

  -- PUBLIC's own ACL entry, which is what `revoke all ... from public` exists to
  -- clear. grantee 0 is PUBLIC; a row here would grant every present and future
  -- role at once, including any the Data API provisions later.
  select count(*) into v_n
    from pg_class c, aclexplode(c.relacl) a
   where c.oid = 'public.usda_foods'::regclass and a.grantee = 0;
  if v_n <> 0 then
    raise exception 'U3 FAIL: % PUBLIC grant(s) remain on usda_foods', v_n;
  end if;

  -- U4. The re-export contract: a second apply of the seed is an UPSERT, not a
  -- duplicate-key failure and not a second row. `imported_at = now()` rides
  -- along so "which release is live" stays answerable.
  insert into public.usda_foods (fdc_id, description, data_type, nutrition)
  values (999000001, 'Oats, whole grain, rolled, dry', 'foundation',
          '{"kcal": 380.0, "protein_g": 13.5}'::jsonb)
  on conflict (fdc_id) do update set
    description = excluded.description,
    data_type   = excluded.data_type,
    nutrition   = excluded.nutrition,
    imported_at = now();

  select count(*) into v_n from public.usda_foods where fdc_id = 999000001;
  if v_n <> 1 then
    raise exception 'U4 FAIL: the upsert left % rows at fdc_id 999000001, expected 1', v_n;
  end if;
  select description, data_type into v_desc, v_txt
    from public.usda_foods where fdc_id = 999000001;
  if v_desc <> 'Oats, whole grain, rolled, dry' or v_txt <> 'foundation' then
    raise exception 'U4 FAIL: the upsert kept the old values (%, %)', v_desc, v_txt;
  end if;

  -- U5. ADR catalog D5, unchanged by this spec. Spec 45 adds a second writer of
  -- `catalog_items.nutrition` — the Worker, as table owner — and that must not
  -- have reopened the global catalog to clients. SELECT stays; the three writes
  -- stay gone (migration 0046, SCH-07).
  if not has_table_privilege('authenticated', 'public.catalog_items', 'select') then
    raise exception 'U5 FAIL: authenticated cannot SELECT catalog_items — search is broken';
  end if;
  foreach v_priv in array array['insert', 'update', 'delete'] loop
    if has_table_privilege('authenticated', 'public.catalog_items', v_priv) then
      raise exception 'U5 FAIL: authenticated holds % on catalog_items (D5)', v_priv;
    end if;
  end loop;

  -- U6. The panel's read contract, and an honest note about its limits: this
  -- pins the COLUMN's behaviour, not the generator's. jsonb cannot store a
  -- number as anything but a number, so the round-trip below would pass on any
  -- correct database — what it is really here to catch is a future migration
  -- that changes the column's type or its default handling out from under the
  -- Worker, which reads these values as JS numbers with no coercion.
  --
  -- The boundary it CANNOT enforce is asserted explicitly a few lines down: a
  -- quoted "380.0" is valid jsonb inside a valid object, so nothing in this
  -- schema stops one. Keeping numbers numeric is `export-usda-foods.py`'s job
  -- (its `num()` formats bare numerics and `validate()` re-parses every literal
  -- and rejects a non-number), and that is worth stating where someone reading
  -- this file might otherwise assume the database has it covered.
  select (nutrition->>'kcal')::numeric into v_kcal
    from public.usda_foods where fdc_id = 999000001;
  if v_kcal <> 380.0 then
    raise exception 'U6 FAIL: kcal read back as %, expected 380.0', v_kcal;
  end if;
  if jsonb_typeof(
       (select nutrition->'kcal' from public.usda_foods where fdc_id = 999000001)
     ) <> 'number' then
    raise exception 'U6 FAIL: kcal is not a jsonb number';
  end if;
  -- The boundary, asserted rather than assumed: a STRING-valued nutrient is
  -- accepted by this schema. Nobody should read the CHECK above and conclude
  -- otherwise; the guarantee lives in the generator, and this row proves where
  -- the line is. (Rolled back with everything else.)
  insert into public.usda_foods (fdc_id, description, data_type, nutrition)
  values (999000008, 'String kcal', 'foundation', '{"kcal": "380.0"}'::jsonb);
  if jsonb_typeof(
       (select nutrition->'kcal' from public.usda_foods where fdc_id = 999000008)
     ) <> 'string' then
    raise exception 'U6 FAIL: the string-kcal boundary probe did not behave as documented';
  end if;

  -- An absent key means UNKNOWN, never zero — the rule the whole panel shape
  -- rests on, and the reason `caffeine_mg` is omitted rather than stored as 0.
  -- `jsonb_exists(...)` rather than the `?` operator: identical semantics, and it
  -- survives being pasted into any tool that treats `?` as a bind placeholder.
  if (select jsonb_exists(nutrition, 'caffeine_mg')
        from public.usda_foods where fdc_id = 999000001) then
    raise exception 'U6 FAIL: an unreported nutrient materialized as a key';
  end if;

  -- U7. `imported_at` defaults rather than requiring the generator to write it —
  -- the seed file names four columns and this is the fifth.
  select imported_at into v_imported
    from public.usda_foods where fdc_id = 999000006;
  if v_imported is null then
    raise exception 'U7 FAIL: imported_at did not default';
  end if;
  -- now() is frozen inside a transaction, so this is an equality, not a window.
  if v_imported <> now() then
    raise exception 'U7 FAIL: imported_at is %, expected the transaction timestamp %',
      v_imported, now();
  end if;

  return 'ALL 7 ASSERTIONS PASSED';
exception
  when others then
    return 'FAILED [' || sqlstate || ']: ' || sqlerrm;
end
$fn$;

select pg_temp.check_0047() as result;

rollback;
