-- 0053: five integrity fixes on the household write path — three from the
-- 2026-09-04 area-D audit (FIND-004, FIND-013, FIND-014) and two column-scope
-- grants from the same day's grants review (`households`, `grocery_items`,
-- both at the foot of this file). Two of the first three live in
-- `merge_add_items`, which is re-created here in full because applied
-- migrations are immutable: 0019 is the last file that defined it and it stays
-- exactly as it is (specs/MIGRATIONS.md). This body is 0019's, with the three
-- changes marked `0053` inline and nothing else touched.
--
-- ============================================================================
-- FIND-004 — the spice branch read only the INCOMING category, and a merge
--            never refreshed the stored one.
-- ============================================================================
--
-- Spices are one row per spice per location: they dedupe on name + location
-- alone, and a re-add refreshes the expiry clock rather than opening a second
-- expiry cohort (specs/item-batches.md §Model, audit B9). 0019 decided that
-- with `v_batched := rec.category <> 'spices'` — a test on the incoming row
-- only. Whether an add is a spice add is a property of the FOOD, not of the
-- payload that happens to carry it, and the two orderings of the same two adds
-- diverged:
--
--   free-text "Cumin" (category 'other', no catalog link), then the catalog
--   Cumin ('spices'):
--     incoming is a spice ⇒ unbatched ⇒ it matched the stored row on
--     name + location and merged — but the UPDATE list had no `category`, so
--     the row kept `'other'` forever while carrying a spice's catalog link. It
--     then sorts under "Other" on every screen that groups by category, and
--     every LATER add re-decides batched-ness from a category that is wrong.
--
--   catalog Cumin ('spices'), then free-text "cumin" ('other'):
--     incoming is NOT a spice ⇒ batched ⇒ the match also required equal
--     `expires_at`, and the stored row carries the catalog's shelf-life date
--     while the free-text add carries none ⇒ no match ⇒ a SECOND row for a
--     food the spec says has exactly one.
--
-- THE RULE (0053): an add is a spice add when EITHER side says so — the
-- incoming category, or the category stored on a same-name row already in that
-- location. `v_spice` below is that disjunction, computed before the lookup
-- because it shapes the lookup's predicate.
--
-- Why the disjunction and not `coalesce(existing.category, rec.category)`,
-- which is how the finding phrased it: coalesce lets the STORED category win
-- outright, which fixes the second ordering and RE-BREAKS the first — stored
-- 'other' + incoming 'spices' would resolve to 'other', demand equal expiry,
-- and split the row that 0019 at least merged. Only "either side" converges
-- both orderings, and converging both is the acceptance criterion. Coalesce is
-- the right shape for reading the category (the stored row is the authority
-- once one exists); it is the wrong shape for deciding identity, where the two
-- adds have to agree no matter which arrives first.
--
-- The second half is the refresh: on a merge that BACKFILLS the catalog link
-- (stored link null, incoming link set — 0014's D5 behaviour, unchanged), the
-- category now rides along with the link it just acquired. The catalog row is
-- the authority on what a food is; a free-text row that becomes catalog-linked
-- should not keep the guess the user made before the link existed. Trigger
-- condition and all: exactly the rows `catalog_item_id` itself changes on.
--
-- Both orderings above now end at ONE row carrying `category = 'spices'` and
-- the catalog link.
--
-- ONE BEHAVIOUR CHANGE BEYOND THE FINDING, and it is deliberate (lead call,
-- 2026-09-04; the PR keeps it as an escalation so it can be reversed before the
-- apply). A spice re-add that carries NO date now KEEPS the stored one instead
-- of clearing it. 0019 wrote `else rec.expires_at` literally, and under 0019
-- that was survivable: a dateless free-text re-add of a catalog spice did not
-- merge at all, so the dated row lived on beside the new one. Merging them --
-- which is the whole point of FIND-004 -- makes that same write destructive,
-- because there is now only one row and the date has nowhere else to be. It
-- would vanish from the expiring screen and the digest on a re-add the user
-- experiences as "I bought more cumin". A dateless payload is an ABSENCE of
-- information, not a claim that the jar has no date, so the safer reading wins
-- and B9's "new jar, new clock" keeps applying whenever a date is actually
-- supplied.
--
-- Two knock-on notes, deliberate:
--   * A same-name, different-category collision in one location (stored
--     "Pepper" the spice, incoming "Pepper" the produce) merges into the spice
--     row. That is not new — 0019 merged the same pair in the other direction —
--     and it follows from the spec's identity being name + location. Splitting
--     it would need a wider identity, which is a supersession of ADR
--     data-model D3, not a bug fix.
--   * A null incoming `category` (a payload that omits the key) is now treated
--     as non-spice consistently. 0019 let `NULL <> 'spices'` make `v_batched`
--     NULL, which read as "batched" in the WHERE and as "spice" in the UPDATE —
--     two different answers in one iteration. The INSERT path still raises
--     23502 on a null category, exactly as before; nothing here starts
--     accepting a payload that used to fail.
--
-- ============================================================================
-- FIND-013 — `p_items` was uncapped, and the advisory lock is household-wide.
-- ============================================================================
--
-- The loop is O(rows) selects and writes while holding
-- `inventory_merge:<household>`, so one oversized call stalls every other add
-- in that household for as long as it runs. Capped at 200, raised BEFORE
-- `pg_advisory_xact_lock` and after the membership check — 0038's ordering, for
-- 0038's reason: a caller who is refused must never have been able to take the
-- lock first.
--
-- It raises **SQLSTATE AMB01**, a user-defined code, rather than the
-- `check_violation` every other refusal in this schema uses -- see the inline
-- note at the raise. The client keys its copy off it, so the code is part of
-- this migration's contract once applied.
--
-- 200 is comfortably above every legitimate caller:
--   * the receipt route slices the model's output to `MAX_ITEMS = 60`
--     (`supabase/functions/_shared/receipt.ts:29`);
--   * the capture basket commits what the user staged by hand, one barcode
--     scan or one receipt at a time (`BasketReview.tsx`);
--   * restock commits the ticked rows of one grocery list
--     (`RestockReview.tsx`).
-- Neither of the last two carries a cap of its own, so `MERGE_ADD_MAX_ITEMS` in
-- `src/features/inventory/batches.ts` mirrors this number and `useBulkAddItems`
-- refuses locally before spending a round trip; `mergeAddCap.test.ts` parses
-- THIS file and fails if the two ever drift.
--
-- ============================================================================
-- FIND-014 — `zone_id` had no scope check.
-- ============================================================================
--
-- 0028 gave `inventory_items` a trigger asserting that `location_id` belongs to
-- `household_id`, for reasons that apply verbatim to `zone_id`: a zone belongs
-- to exactly one location, nothing checked that an item's zone belongs to the
-- item's own location, and PostgREST exposes the column to any member's PATCH.
-- A mismatched pin is invisible rather than loud — `groupLocationItems` drops a
-- pin whose zone is not on the screen's own list (`grouping.ts:89`), so the row
-- silently falls back to its category section and the user's pin appears to
-- have been ignored. It also disappears for good when the OTHER location's zone
-- is deleted, because the FK is `on delete set null`.
--
-- Extended in the same function rather than a second trigger: it is one
-- invariant ("this row's placement is internally consistent"), one raise, one
-- place to read. Checking `zones.location_id = new.location_id` covers the
-- household too, transitively — a zone's location's household is already
-- pinned by the check above it.
--
-- The trigger is dropped and re-created to widen its column list to `zone_id`;
-- `create or replace trigger` would do it on PG14+, but drop-then-create is the
-- repo's precedent (0049) and portable further back. Both statements are in one
-- transaction under `-1`, so there is no window with no trigger.
--
-- Nothing in the client needs to change: pins are always chosen from the
-- location's own zone list (`location/[id]/index.tsx:179`, `item/[id].tsx:277`)
-- and a move already nulls `zone_id` (`hooks.ts:451`). The trigger enforces
-- what the app already does, for the write paths that are not the app.
--
-- ============================================================================
-- FIND-018 — a comment this migration deliberately does NOT fix.
-- ============================================================================
--
-- `supabase/migrations/0038_sweep_adds_to_list.sql:149` says "SECURITY INVOKER,
-- so this is reach, not privilege" above its `service_role` grant, on a
-- function declared `security definer` forty lines earlier (0038:42). The claim
-- is false and the correction is recorded in docs/adr/data-model.md D4
-- (2026-08-24 truth pass). 0040 re-created the same function and dropped the
-- sentence, so 0040 is clean and 0038 is the only MIGRATION carrying it. Two
-- archived apply bundles embed the same paragraph, because they were assembled
-- out of 0038 — `db/apply/production-0023-0037-0038.sql:353` and
-- `db/apply/2026-08-08-pending.sql:362`. Leave those alone whatever happens to
-- 0038: they are records of what was actually run on a date, not instructions,
-- and editing a record to make it read better is how you lose the ability to
-- trust it. Only the live migration needs the corrected comment.
--
-- It is left alone here on purpose: applied migrations are immutable, and this
-- migration does not re-create `clear_stale_out_items`, so it has no honest
-- place to restate the grant. **The next migration that re-creates
-- `clear_stale_out_items` must carry the corrected comment.** Recorded in
-- specs/MIGRATIONS.md §Pending applies as well, so it is not only in a file
-- nobody re-reads.
--
-- ============================================================================
-- WHAT THIS MIGRATION DOES NOT DO: heal the rows already stuck.
-- ============================================================================
--
-- FIND-004 stops the divergence going forward. It does NOT repair a row that
-- already sits at `category = 'other'` while holding a spice's catalog link,
-- and no later add will repair it either: the category refresh above is
-- conditioned on the link BACKFILL (`v_target.catalog_item_id is null and
-- rec.catalog_item_id is not null`), and a stuck row's link is already set, so
-- every future merge takes the `else category` arm and leaves it exactly as it
-- is. Nor can the user fix it by hand — `ItemPatch`
-- (`src/features/data/repository.ts`, `ItemPatch`) has no `category`, so no screen
-- writes that column. Deleting the row and re-adding it is the only route the
-- app offers today.
--
-- Count them on the rehearsal branch before deciding whether that matters:
--
--   select count(*)
--     from public.inventory_items i
--     join public.catalog_items c on c.id = i.catalog_item_id
--    where c.category = 'spices' and i.category <> 'spices';
--
-- (Add `and i.status <> 'out'` to see only rows still on a shelf; out rows leave
-- on the sweep anyway.)
--
-- **The backfill itself is a PRODUCT decision, deliberately not taken here**:
-- it asks whether a catalog link should override a stored category in general,
-- which is a rule about who owns a food's category — not a bug fix. Taking it
-- silently inside a corrective migration would also rewrite rows whose category
-- a user may have chosen on purpose, if that ever becomes editable. If the
-- count comes back non-trivial and Everett says the link wins, the repair is a
-- guarded one-statement UPDATE in its own migration, and it should be narrowed
-- to `c.category = 'spices'` rather than run across every category.
--
-- ============================================================================
-- PORTABILITY (CLAUDE.md, specs/MIGRATIONS.md): schema-qualified throughout, no
-- `auth.users`, no `realtime.*`, and privileges are granted by revoking from
-- PUBLIC rather than naming the unauthenticated role (Supabase `anon`, Neon
-- `anonymous`). 0023 is the pattern. `merge_add_items` moves from 0019's
-- `set search_path = public` to `set search_path = ''` in the process, which is
-- why every name below is qualified.
--
-- Verify on a Neon branch with db/asserts/0053_merge_integrity.sql, then apply
-- to the main branch by hand — there is no runner (specs/MIGRATIONS.md).
-- ============================================================================

create or replace function public.merge_add_items(p_household_id uuid, p_items jsonb)
returns integer
language plpgsql volatile
-- INVOKER, unchanged from 0014: RLS stays the authority and this RPC only adds
-- atomicity. The membership check below exists to turn a bare 42501 into a
-- readable error, and — since 0053 — to keep a non-member away from the lock.
set search_path = ''
as $$
declare
  rec       record;
  v_name    text;
  v_key     text;
  v_spice   boolean;
  v_batched boolean;
  v_target  public.inventory_items%rowtype;
  v_count   integer := 0;
begin
  -- RLS already blocks non-members; this check only turns a bare 42501 into a
  -- readable error. First, so that a non-member cannot take the household
  -- advisory lock below and stall a household's adds (0038's ordering).
  if not public.is_household_member(p_household_id) then
    raise exception 'not a member of this household';
  end if;
  if p_items is null or jsonb_typeof(p_items) <> 'array' then
    raise exception 'p_items must be a json array';
  end if;

  -- 0053 (FIND-013). Before the lock, after membership: the loop below holds a
  -- household-wide lock for as long as it runs, so an unbounded payload is a
  -- denial of service against the household's own adds. 200 is far above every
  -- real caller (the receipt route caps itself at 60); see the header.
  if jsonb_array_length(p_items) > 200 then
    -- AMB01, not check_violation: 23514 is what the placement trigger raises,
    -- what every CHECK on every column raises, and what 0051's caps raise, so a
    -- client that saw it learned only "something was refused". This is the one
    -- refusal the UI has specific, actionable copy for -- untick some rows and
    -- send the rest -- and it needs to tell it apart from a bad zone or an
    -- over-long name. `AM` is not a class PostgreSQL defines, so AMB01 cannot
    -- collide with a real one. THE CODE IS PERMANENT ONCE THIS APPLIES:
    -- `isBulkAddCap` in src/features/inventory/batches.ts matches on it.
    raise exception 'merge_add_items accepts at most 200 items per call (got %)',
      jsonb_array_length(p_items)
      using errcode = 'AMB01';
  end if;

  -- One merge writer per household at a time: FOR UPDATE below covers the
  -- matched-row race, but two concurrent adds that BOTH insert (no row to
  -- lock) would still create twins without this. Household-wide, so bulk
  -- calls cannot deadlock on per-row lock ordering.
  perform pg_advisory_xact_lock(hashtextextended('inventory_merge:' || p_household_id::text, 0));

  for rec in
    select *
    from jsonb_to_recordset(p_items) as x(
      location_id uuid,
      catalog_item_id uuid,
      name_override text,
      category public.food_category,
      expires_at date,
      expiry_source public.expiry_source_kind,
      notes text
    )
  loop
    v_name := coalesce(rec.name_override, (select name from public.catalog_items where id = rec.catalog_item_id));
    if v_name is null or btrim(v_name) = '' then
      raise exception 'item needs a name or a catalog link';
    end if;
    v_key := public.normalize_item_name(v_name);

    -- 0053 (FIND-004). Spice-ness is a property of the food, so EITHER side may
    -- assert it: the incoming category, or a same-name row already stored in
    -- this location. `is not distinct from` keeps a null incoming category out
    -- of three-valued territory — `v_spice` and `v_batched` are always a real
    -- boolean from here down, which 0019's `rec.category <> 'spices'` was not.
    -- The probe runs under the advisory lock and inside this transaction, so it
    -- also sees rows inserted by earlier iterations of this same call.
    v_spice := rec.category is not distinct from 'spices'::public.food_category
      or exists (
        select 1
        from public.inventory_items i
        left join public.catalog_items c on c.id = i.catalog_item_id
        where i.household_id = p_household_id
          and i.location_id = rec.location_id
          and i.status <> 'out'
          and i.category = 'spices'::public.food_category
          and public.normalize_item_name(coalesce(i.name_override, c.name, '')) = v_key
      );
    v_batched := not v_spice;

    select i.* into v_target
    from public.inventory_items i
    left join public.catalog_items c on c.id = i.catalog_item_id
    where i.household_id = p_household_id
      and i.location_id = rec.location_id
      and i.status <> 'out'
      and public.normalize_item_name(coalesce(i.name_override, c.name, '')) = v_key
      and (not v_batched
           or coalesce(i.expires_at, date '9999-12-31') = coalesce(rec.expires_at, date '9999-12-31'))
    order by i.added_at
    limit 1
    for update of i;

    if found then
      update public.inventory_items
      set status = 'stocked',
          catalog_item_id = coalesce(v_target.catalog_item_id, rec.catalog_item_id),
          -- 0053 (FIND-004). The catalog row is the authority on what a food
          -- is, so on exactly the merges that backfill the link (stored null,
          -- incoming set) the category follows it. Otherwise the stored value
          -- stands: a free-text re-add must not be able to re-categorise a
          -- catalog-linked row from a guess.
          category = case
                       when v_target.catalog_item_id is null
                            and rec.catalog_item_id is not null
                         then coalesce(rec.category, category)
                       else category
                     end,
          -- 0053. The spice arm refreshes the clock from the incoming add
          -- (audit B9, "new jar, new clock") -- but only when the incoming add
          -- HAS a date. A dateless payload is an absence of information, not an
          -- assertion that the jar has no date, and 0019's literal
          -- `else rec.expires_at` wiped a good date on the strength of it. That
          -- did not matter while a dateless free-text re-add of a catalog spice
          -- landed as a SECOND row (the dated one survived beside it); now that
          -- FIND-004 merges them into one, the same write would take the only
          -- copy of the date and drop the row off every expiry surface.
          expires_at = case when v_batched or rec.expires_at is null
                            then expires_at else rec.expires_at end,
          -- Moves with the date it describes: keeping `shelf_life` next to a
          -- date the estimate did not produce is how a row starts lying about
          -- where its date came from.
          expiry_source = case when v_batched or rec.expires_at is null
                               then expiry_source else rec.expiry_source end,
          notes = coalesce(nullif(btrim(rec.notes), ''), v_target.notes)
      where id = v_target.id;
    else
      insert into public.inventory_items
        (household_id, location_id, catalog_item_id, name_override, category,
         status, expires_at, expiry_source, notes)
      values
        (p_household_id, rec.location_id, rec.catalog_item_id, rec.name_override, rec.category,
         'stocked', rec.expires_at, rec.expiry_source, nullif(btrim(rec.notes), ''));
    end if;
    v_count := v_count + 1;
  end loop;

  return v_count;
end;
$$;

comment on function public.merge_add_items(uuid, jsonb) is
  'Atomic merge-on-add (audit D1, specs/item-batches.md). Identity is normalized '
  'display name + location; batching rows additionally need an equal expires_at, '
  'spices do not. Since 0053 an add counts as a spice add when EITHER the '
  'incoming category or a stored same-name row in that location says ''spices'', '
  'so the two orderings of the same pair of adds converge on one row — and a '
  'merge that backfills catalog_item_id onto a free-text row refreshes that '
  'row''s category from the catalog too. Capped at 200 items per call, raised '
  'before the household advisory lock as SQLSTATE AMB01 (not check_violation, '
  'so a client can tell it from a constraint or a scope refusal).';

-- CREATE OR REPLACE preserves 0014's grants, but restating them costs nothing
-- and makes this file readable on its own. Portable form (0023/0038): revoke
-- from PUBLIC rather than naming the unauthenticated role, which is `anon` on
-- Supabase and `anonymous` on Neon.
revoke all on function public.merge_add_items(uuid, jsonb) from public;
grant execute on function public.merge_add_items(uuid, jsonb) to authenticated;

do $$
begin
  -- Supabase only; Neon has no such role.
  if exists (select 1 from pg_roles where rolname = 'service_role') then
    grant execute on function public.merge_add_items(uuid, jsonb) to service_role;
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- FIND-014: the placement-scope trigger grows a zone clause.
-- ---------------------------------------------------------------------------

create or replace function public.assert_item_location_scope()
returns trigger
language plpgsql
-- DEFINER, unchanged from 0028: the trigger must see `storage_locations` and
-- `zones` rows that the writer's own RLS may hide, or the assertion would pass
-- for the wrong reason. It reads two id columns and raises; it writes nothing.
security definer
set search_path = ''
as $$
begin
  if new.location_id is not null and not exists (
    select 1 from public.storage_locations l
    where l.id = new.location_id and l.household_id = new.household_id
  ) then
    raise exception 'location does not belong to this household'
      using errcode = 'check_violation';
  end if;

  -- 0053 (FIND-014). A zone belongs to exactly one location, so a pin is only
  -- meaningful on an item filed in that same location. Checked after the clause
  -- above, which is what makes this one household-safe by construction.
  if new.zone_id is not null and not exists (
    select 1 from public.zones z
    where z.id = new.zone_id and z.location_id = new.location_id
  ) then
    raise exception 'zone does not belong to this item''s location'
      using errcode = 'check_violation';
  end if;

  return new;
end;
$$;

comment on function public.assert_item_location_scope() is
  'Row trigger on inventory_items: location_id must belong to household_id '
  '(0028) and zone_id, when set, must belong to location_id (0053). Both raise '
  'check_violation. Lives on the table rather than in merge_add_items so it '
  'holds for direct PostgREST writes and for every future write path.';

revoke all on function public.assert_item_location_scope() from public;

do $$
declare
  v_role text;
begin
  -- Nobody calls this by name — it runs as trigger machinery, which does not
  -- check EXECUTE at fire time. 0028's intent, written portably: Supabase's
  -- `anon` and Neon's `anonymous` are named only if they exist.
  for v_role in
    select rolname from pg_roles where rolname in ('anon', 'anonymous', 'authenticated', 'service_role')
  loop
    execute format('revoke all on function public.assert_item_location_scope() from %I', v_role);
  end loop;
end $$;

-- Re-created to widen the column list: a pin written by a bare `PATCH
-- {zone_id}` touches neither location_id nor household_id, so 0028's trigger
-- never fired on the one statement the app actually uses to pin.
drop trigger if exists inventory_items_location_scope on public.inventory_items;

create trigger inventory_items_location_scope
  before insert or update of location_id, household_id, zone_id on public.inventory_items
  for each row execute function public.assert_item_location_scope();

-- ===========================================================================
-- COLUMN SCOPE, part 1: `households` (grants review 2026-09-04)
-- ===========================================================================
--
-- `grant all on households to authenticated` (0001-era, restated at
-- db/neon-grants.sql:57) hands members table-wide UPDATE, and 0046 narrowed
-- only INSERT. `households_update` is `using/with check (is_household_owner(id))`
-- — it scopes ROWS and, as always, never COLUMNS. So an owner may PATCH any
-- column of their own household, including three the app never writes:
--
--   * `created_by` — the client's "home household", the one household a user
--     cannot leave or delete (`src/features/households/membership.ts:10-27`,
--     keyed on `created_by`, NOT on membership role). An owner who rewrites it
--     to another member's id hands that member a floor they never asked for and
--     drops their own — an account whose only household is somebody else's is
--     bounced into onboarding. It does NOT move RLS ownership:
--     `is_household_owner` reads `household_members.role` (0008:11-16), so the
--     forged value is a lie the CLIENT believes and the database does not,
--     which is the harder kind to notice.
--   * `id` — re-keying a live household; every FK is `on delete cascade`, so
--     the write either fails loudly or strands the lot.
--   * `created_at` — cosmetic, and no reason to be writable.
--
-- The fix is the SEC-06 move 0046 made for `household_invites` and 0050 made
-- for `recipes`: revoke the table-level UPDATE and re-grant it per column the
-- client actually patches. That set is exactly, and is checked against, the
-- client's own write paths:
--
--   * `name`, `auto_clear_out_days`, `auto_add_out_to_list` — `HouseholdPatch`
--     (`src/features/data/repository.ts`, `HouseholdPatch`), written by `useUpdateHousehold`;
--   * `invite_code` — rotation, written directly by `regenerateInvite`
--     (`serverRepository.ts:610-617`), because PostgREST cannot express
--     `set x = default` (0046 §4 documents this and gave the column its shape
--     CHECK; that constraint and this grant are the pair).
--
-- INSERT stays revoked (0046) — `create_household` is the only path — and
-- nothing else in the schema updates `households` at all: no RPC touches it,
-- and the Worker never writes it.
--
-- **This ends "columns added later are covered" for `households`.** A new
-- client-writable column needs an explicit grant line here AND in
-- `db/neon-grants.sql`, exactly as 0050 established for `recipes`.
revoke update on table public.households from authenticated;
grant update (name, invite_code, auto_clear_out_days, auto_add_out_to_list)
  on table public.households to authenticated;

-- ===========================================================================
-- COLUMN SCOPE, part 2: `grocery_items` (grants review 2026-09-04)
-- ===========================================================================
--
-- Same shape, one step worse, because here the column-blind grant walks
-- straight around a check another migration added on purpose.
--
-- `grant all on grocery_items to authenticated` (0020:53, restated at
-- db/neon-grants.sql:53) plus `grocery_items_all`, a `for all` policy scoped by
-- `is_household_member(household_id)`, means any member may PATCH any column of
-- any row on the household list — `added_by` included. 0046 (SCH-08/SEC-15)
-- made `add_grocery_items` refuse a supplied `added_by` unless that person is a
-- member of THIS household (0046:310-322), so the RPC cannot forge a byline;
-- a bare `PATCH {added_by}` never asked the RPC. The list renders the adder's
-- display name (`adder:profiles!grocery_items_added_by_fkey`), so a forged
-- value shows up as "· Alex" against a row Alex never added, and there is no
-- audit trail behind it. `catalog_item_id`, `name` and `household_id` are
-- writable too — the last one MOVES a row to another household the writer
-- belongs to.
--
-- The client's whole update surface is two columns:
-- `GroceryPatch = Partial<Pick<GroceryItem, 'status' | 'category'>>`
-- (`src/features/data/repository.ts`, `GroceryPatch`), written by `updateGroceryItem`.
-- Every INSERT goes through `add_grocery_items`, and the sweep's list write is
-- `clear_stale_out_items`; BOTH are `security definer` (0046:258-268,
-- 0040:125-136), so they run as the owner and neither notices this revoke.
-- SELECT and DELETE are unchanged — the list screen deletes rows directly
-- (`deleteGroceryItem`, `deleteBoughtGroceryItems`, `clearCheckedGrocery`) and
-- those are whole-row operations a policy CAN scope.
--
-- Same rule as above: a future client-writable column needs its own grant line
-- here and in `db/neon-grants.sql`.
revoke insert, update on table public.grocery_items from authenticated;
grant update (status, category) on table public.grocery_items to authenticated;
