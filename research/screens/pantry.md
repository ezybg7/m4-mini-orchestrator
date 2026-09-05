# Ambry — pantry group screen research (2026-09-04)

_Group: Pantry tab · Location · Zones · Expiring · Item. Read against `main@dfcd0f0` (P3 #180, P4 #173 and P7 #178 already landed). Principles: minimal interactions · no keyboard where a control will do · no duplicated headers · iOS grouped-list feel · Android-clean. Sources are numbered at the end; every claim about another app cites one. Companion data: `pantry.json`._

## 1. Pantry overview tab — `src/app/(tabs)/index.tsx`

**Today.** LargeTitle "Pantry" (household subtitle only when in >1), an always-visible SearchField, an Expiring Soon row whose badge earns its colour (neutral/orange/red) → `/expiring`, a 2-column grid of location cards ("N foods" / "Empty") → `/location/[id]`, footer "Add location" + ScorecardCard. All-empty pantry → one empty state. Typing swaps the grid for search results grouped by location with full row behaviour. **Cost:** 1 tap to a shelf or to expiring; Low/Out across the pantry need a shelf + its filter.

**Apps.**
- **Apple Reminders home** — count-carrying smart-list tiles (Today, Scheduled, All, Flagged…) above "My Lists" rows with counts; custom smart lists filter across every list [2][4]. *Borrow:* status tiles as destinations — Ambry shows one state (Expiring) and hides Low and Out; and lists as rows, which survive eight shelves where a card grid does not.
- **Apple Home** — a category row (Lights, Security, Climate…) filtering the whole home above Favorites/Scenes/Rooms tiles; "Edit Home View" and "Reorder Sections" behind one ellipsis [17][18]. *Borrow:* states as chips over places as tiles; arrangement in one menu with a drag mode (Ambry cannot reorder locations).
- **Grocy stock overview** — header status buttons with counts that filter the table ("X products are overdue", Due soon, Below min. stock), location/product-group filters, per-row consume/open/spoiled [15][16]. *Borrow:* counters that ARE filters; and the boundary lesson — Grocy needed three changelog fixes to make "due soon" include today and "overdue" exclude tomorrow; Ambry's `urgency()` already encodes this and any counter must reuse it.
- **Sortly** — home summary of item/folder/value totals with low-stock alerts; search across the whole inventory; mobile tabs Workflows · Items · Search · Alerts [21][22]. *Borrow:* a household total plus an attention feed.
- **CozZo / NoWaste** — CozZo's "At Home" has "All Items" and "Spaces" views with a Due Time bar per item [26]; NoWaste stacks Freezer/Fridge/Pantry lists with counts and sorts by expiry, name or category [24][25]. *Borrow:* a pantry-wide view beside the by-space one.

**Directions.**
- **A. Reminders home.** Tiles Expiring · Low · Out · All (counts; each a destination — Low/Out reuse the search SectionList with a stock filter preset) over inset location rows (icon · name · "N foods" · chevron); footer unchanged; empty/error states unchanged. *Borrowed:* Reminders tiles [2], Grocy counters [16]. *Cost:* 1 tap to a shelf (same), 1 tap to any pantry-wide state. *Trade-off:* four controls above the fold; spec 26 deliberately kept filters off the overview — escalation. One idiom: tile = state, row = place.
- **B. One long shelf list.** No grid: each location is a pressable section header (icon · name · count) with its three soonest-expiring rows inline and "Show all N ▸"; a SegmentedControl All · Expiring · Low · Out on the whole pantry replaces the summary row; search filters in place. *Borrowed:* CozZo all-items view [26], NoWaste lists [24]. *Cost:* 0 taps to see what goes first on every shelf. *Trade-off:* the heaviest read on the home tab, the longest scroll, and it re-opens the second door to the expiring room Everett closed on 08-04.
- **C. Home-app chips over the grid.** Keep the cards; a chip row "Expiring 3 · Low 2 · Out 5" opens a triage BottomSheet of SwipeRows (Used / +2 days / List, Cancel); LargeTitle `right` = OverflowMenu (New location · Reorder locations via the zones drag · Household). *Borrowed:* Home's category row and ellipsis [18], Sortly's alerts feed [21]. *Cost:* triage 1 tap + swipe; add location 2 taps (was a scroll). *Trade-off:* a sheet over the home is a new layer; reordering locations is a spec 22 out-of-scope item — escalation.

## 2. Location screen — `src/app/location/[id]/index.tsx`

**Today.** Header "🧊 Fridge" + one OverflowMenu (Edit · Zones · Move all items to… · Delete). Toolbar: description, once-per-device out-rows hint, SearchField, SegmentedControl All · Expiring · Low · Out beside Select (→ Select all / Cancel). Zone sections then category sections; rows = tile · name (struck when out) · "added Sep 3" · urgency badge · tap-to-cycle status chip (out pops a Delete toast) · trash when out · long-press selects. Selection bar: Move (undoable) · Pin (Alert of zones) · Delete (undo toast). Empty and filtered-empty states carry glyphs. **Cost:** item 1 tap; status 1–2 chip taps; every location action 2 taps.

**Apps.**
- **Apple Reminders (a list)** — sections collapse on tap; ellipsis → "Select Reminders", "Sort By", "View as Columns"; selection shows a bottom toolbar (date, move, delete, flag) [1][5]. *Borrow:* Select in the menu with long-press kept; collapsible headers.
- **Things 3 (a project)** — swipe right opens When, swipe left selects and a drag down the edge extends the selection; pull down to search [9]. *Borrow:* one swipe vocabulary on every list (the S3 fix); search that costs nothing until pulled.
- **Todoist** — swipe actions chosen once in Settings from Complete, Schedule, Delete, Reminders; two-finger swipe selects [13]. *Borrow:* a single household-wide swipe rule.
- **Grocy** — filter buttons carry counts; row verbs are events (consume, open, spoiled), not a cycle [15]. *Borrow:* "Out 5" on the segment; name the event, not the state.
- **Apple Files / Mail** — More → Select → bottom actions [30]; Mail's full swipe fires the outermost action, actions chosen in Settings [14]. *Borrow:* full-swipe for the common verb.

**Directions.**
- **A. Reminders list.** Search behind a header magnifier; OverflowMenu gains "Select items" and "Sort by" (escalation: spec 25 fixes the sort); segments show counts; SectionHeader becomes pressable and collapses (persisted); rows and bar unchanged. *Borrowed:* [5][9][15]. *Cost:* search +1 tap; select 2 taps or 1 long-press; ~52pt returned to food on every shelf. *Trade-off:* nothing to learn, one tap dearer to search.
- **B. Swipe triage, no chip cycle.** Rows adopt the Expiring screen's two-edge SwipeRow — leading Low / Out (full swipe = Out), trailing +2 days / List; out rows get Back in stock / Delete; the chip becomes a passive label; rotor actions mirror everything; one first-use hint. *Borrowed:* Things gestures [9], Mail full-swipe [14], Grocy events [15]. *Cost:* any status 1 swipe (Stocked→Out was 2 taps); add-to-list from a shelf 1 swipe (impossible today). *Trade-off:* swipes are undiscoverable, and the chip cycle was Everett's 07-24 decision (spec 24) — escalation. Closes S3 for the pantry half.
- **C. Flat urgency list with count chips.** Sections off by default; one list sorted by urgency; a chip row "All 24 · Expiring 3 · Low 2 · Out 5 · Door 4 · Top shelf 6" replaces the segments; "Group by category" in the menu. *Borrowed:* NoWaste sort/filter [24], Grocy counters [16], Home's chip row [18]. *Cost:* filter 1 tap with a count; zone filter 1 tap. *Trade-off:* contradicts spec 25 twice and SPEC.md §3's self-organising sections — the largest escalation here; chips wrap at accessibility sizes.

## 3. Zones editor — `src/app/location/[id]/zones.tsx`

**Today.** Pushed "Zones" screen: intro, one GroupedRow per zone with a boxless rename Input (pencil glyph, blur-commit, empty reverts), "N items", trash (always confirmed) and a drag handle (200ms, optimistic, Move up/down for VoiceOver); "No zones yet" + an add row (Input + Add). Pinning lives elsewhere (multiselect Pin, item Zone row). **Cost:** reorder 1 drag; rename tap + keyboard + blur; add tap + keyboard + return; delete tap + confirm.

**Apps.**
- **Apple Reminders sections** — managed in the list: New Section from the ellipsis, tap a name to rename, hold to drag, tap to collapse, swipe left to delete; unsectioned reminders sit under "Others" [1][4]. *Borrow:* no separate editor; "Others" = Ambry's category sections.
- **Things 3 headings** — create by dragging the + to the edge; dragging a heading moves its to-dos; move to-dos under a heading from the selection toolbar; archive [10]. *Borrow:* create in place; pin from selection (validates Ambry's Pin).
- **Apple Notes folders** — hold → Rename / Delete; drag to move; swipe left to delete [19]. *Borrow:* rename as a context action, not a live field.
- **Trello lists** — tap the title to edit in place; drag to reorder; list menu (Move, Archive, Sort…); collapse [20]. *Borrow:* rename on tap, rarities in a menu.
- **iOS edit mode / Home "Reorder Sections"** — a table enters Edit before rows reorder or delete; Home drags section handles then Done [31][18]. *Borrow:* an explicit mode that separates reading from arranging.

**Directions.**
- **A. Sections in place (delete the screen).** OverflowMenu "New zone…" (TextPrompt); zone headers become pressable → BottomSheet (Rename… · Move up · Move down · Delete zone · Cancel); long-press a header to drag (reuse the pan + `dropIndex` on section heights); pinning unchanged. *Borrowed:* Reminders sections [1], Notes rename [19]. *Cost:* new zone 2 taps + keyboard; rename 2 taps + keyboard; reorder 1 drag on the shelf itself. *Trade-off:* one screen fewer, but headers gain gestures and drag inside a SectionList is harder than in the editor's ScrollView; spec 4 names the editor — escalation; Maestro re-selectoring.
- **B. iOS edit mode.** Keep the screen: SettingsRows (name · "N items" · chevron → TextPrompt rename); header Edit/Done reveals red minus + handle; "Add zone…" row (TextPrompt); one-line intro. *Borrowed:* HIG edit mode [31], Home's handle mode [18], Trello's split [20]. *Cost:* reorder Edit + drag + Done (3 vs 1); delete 3 vs 2; keyboard only for a name. *Trade-off:* costs taps on rare actions to buy a screen that cannot be edited by accident — the most familiar of the three (Settings › Mail › Accounts).
- **C. One zones sheet for editing and pinning.** The editor becomes a BottomSheet on the location screen; the same sheet is the pin picker (tap-to-pin rows, Unpin, footer "Edit zones") replacing `promptZone`'s Alert, which cannot scale past six. *Borrowed:* Things' move-under-heading [10], Reminders in-list sections [1]. *Cost:* manage zones 2 taps from anywhere on the shelf, no push; pin unchanged with a real list. *Trade-off:* drag inside a scrolling modal is the hardest gesture pairing in the app; two jobs in one sheet risks S11's mixed contracts.

## 4. Expiring screen — `src/app/expiring.tsx`

**Today.** Empty-titled bar with "Add all" (tinted, cart) in the right slot; LargeTitle "Expiring Soon" + "N items this week"; one tinted CTA "See what you can make with these"; sections Overdue (danger tone) · Today · Tomorrow · "In N days · Sep 8"; rows = SwipeRow (leading Used → out; trailing +2 days, List) around ItemRow (subtitle = shelf; trash → delete with undo; rotor mirrors the swipes). Empty: check glyph + one sentence. **Cost:** each verb 1 swipe; Add all 1 tap; Cook 1 tap.

**Apps.**
- **Apple Reminders Scheduled/Today** — Past Due, Today, Tomorrow, rest of month, later months; Today splits Morning/Afternoon/Tonight; completion is a tap on the circle; swipe left deletes [2][3]. *Borrow:* the frequent verb as a visible tap; widening buckets for a longer horizon.
- **Todoist Upcoming** — an Overdue section with a "Reschedule" button that re-dates everything overdue at once; a section per day; drag a task onto another day [11]. *Borrow:* a bulk action on Overdue; drag-to-day as a picker-less re-date.
- **Things 3 Today/Upcoming** — overdue inside Today with an optional "This Evening" section; the next seven days listed separately; swipe right opens When (Today · This Evening · Someday · calendar · Clear) [6][7][9]. *Borrow:* the swipe opens a small picker rather than firing one fixed nudge; a second axis inside the day view.
- **Apple Mail** — swipe actions chosen in Settings; a full swipe fires the outermost action [14]. *Borrow:* full-swipe = the outer trailing action (needs a SwipeRow flag).
- **CozZo / Fridgely / Pantry Check** — daily reminders for expire-today / soon / expired / restock and a "Cook Expiring Products" board ranked by expiring-product count [27]; Fridgely widens "expiring soon" to 15–30 days [29]; Pantry Check's Expiring Items screen sorts by alert type [28]. *Borrow:* a user-set horizon; a count on the Cook link ("uses 3 of these").

**Directions.**
- **A. Triage inbox.** A leading 44pt circle on each row (tap → Used, check animation, toast + Undo) with the swipe kept; Overdue header carries a small tinted "Snooze all +2d"; the Cook CTA and Add all move into a header OverflowMenu so the list opens on food. *Borrowed:* Reminders' circle [3], Todoist's Reschedule [11]. *Cost:* Used 1 visible tap; all overdue 1 tap + undo; recipes 2 taps (was 1). *Trade-off:* a new row element and a tap added to the one body CTA P7 kept; the bulk undo must name every row.
- **B. Two cuts: by day, by shelf.** SegmentedControl By day · By shelf (persisted); by shelf = a section per location (danger tone when the whole shelf is overdue) sorted by soonest date, rows by urgency, subtitle becomes "added Sep 3". *Borrowed:* CozZo's two views [26], Things' second axis [6], NoWaste placement filter [24]. *Cost:* 1 tap to switch; verbs unchanged. *Trade-off:* a control returns above the first row; the by-shelf cut hides the red Overdue header. Cheap: `groupItemsByLocation` exists. Answers the open-fridge moment.
- **C. One date vocabulary.** The trailing "+2 days" becomes "Later" → BottomSheet with the item screen's +3d · +1w · +2w · +1m chips, "Type a date", Cancel (all via `snoozedExpiry`, toast + Undo); a footer "Showing 7 days · Change" (3 · 7 · 14, per-device; the Pantry badge follows). *Borrowed:* Things' When on swipe [7], Todoist suggestions [12], Fridgely's range [29]. *Cost:* snooze swipe + 1 tap (was 1 swipe) but any length; horizon 2 taps once. *Trade-off:* a tap on the second-most-frequent verb; the horizon ripples into the digest and filters — Everett's call.

## 5. Item screen — `src/app/item/[id].tsx`

**Today** (rebuilt in #173). Chevron-only bar; hero tile + boxless name field (blur-commit) + "Category · added Sep 3"; STORAGE Location ▸ · Zone ▸ · Status segmented; EXPIRY value "Sep 12 · 5d" + provenance, chips +3d +1w +2w +1m (immediate, Undo), "Type a date ▸" → MaskedDateInput (commits on the eighth digit, year-bounded), Clear; What's in it? · Notes · Nutrition · Delete (one Alert). **Cost:** nudge 1 tap; exact date 1 tap + 8 digits; status 1 tap; location 2 taps.

**Apps.**
- **Apple Reminders details** — a grouped sheet (Date with Today / Tomorrow / This Weekend / Date & Time, Time, Repeat, Tags, Location, Flag, Priority, List, Subtasks, Images, URL); the same quick dates sit over the keyboard [3]. *Borrow:* one relative-date set reused everywhere a date is asked; value rows with disclosure (confirms #173).
- **Things 3 When** — Today · This Evening · Someday · calendar · Clear, plus natural language ("tod", "next week", "sat 9am", "17d", "17d from jul9") echoed as a date before Return; the same picker from a row's swipe [7][8][9]. *Borrow:* typed dates that show what they mean before committing.
- **Todoist scheduler** — suggestions (Today, Tomorrow, This weekend, Next week), a calendar with per-day load, a natural-language field, dates coloured red/green/brown/purple by urgency [12]. *Borrow:* urgency-coloured date text; three paths in one control.
- **Fantastical** — one field, live-highlighted parts, and a fallback to the picker when a date cannot be resolved [32]. *Borrow:* the fallback rule.
- **Sortly item** — photos, quantity, min level, tags, notes, custom fields; Quick Actions update quantity without the editor; bulk Min Level [22][23]. *Borrow:* quick actions on the detail; a per-item "remind me when low" threshold.

**Directions.**
- **A. Expiry as one row and a sheet.** One SettingsRow "Expires · Sep 12 · 5d" (value in urgency tone) → BottomSheet: chips Today · Tomorrow · +3d · +1w · +2w · +1m, a pure-JS month grid, Type a date, Clear, Cancel. *Borrowed:* Things' When [7], Todoist's scheduler and colours [12]. *Cost:* nudge 2 taps (was 1); calendar date 3 taps and no keyboard (was 8 digits). *Trade-off:* a tap on the commonest edit, for a calendar before the native picker lands (critique decision 5); rule 7 needs Cancel.
- **B. Typed dates, understood.** Keep the inline chips; "Type a date" discloses one field that parses "12 sep", "fri", "in 10 days", "3w" via a pure `parseExpiryPhrase(text, today, locale)` on `addCalendarDays`, echoes "→ Sep 12 · Fri · 5d", commits on return/blur within `expiryEntryBounds`, and falls back to the masked field when it cannot parse. *Borrowed:* Things NL input [8], Fantastical's fallback [32], Todoist's typed field [12]. *Cost:* exact date 1 tap + 3–6 characters (was 8 digits); nudges unchanged. *Trade-off:* still a keyboard for an exact date; locale ambiguity handled in the echo; new tested logic. Keeps every tap count #173 won.
- **C. Action row under the heading.** Four small tinted buttons — Used · +2 days · Add to list · Move — sharing the Expiring screen's handlers (lifted into one hook); STORAGE merges Location and Zone into "Where · 🧊 Fridge · Door ▸" with a two-step picker. *Borrowed:* Sortly's Quick Actions [22], Things' same-verbs rule [9], Todoist's Schedule action [13]. *Cost:* Used / +2 days / Add to list 1 tap (Add to list was impossible here); zone 3 taps (was 2). *Trade-off:* weight on the quietest screen and "Used" duplicates Status; but it closes the one real gap — no grocery hand-off from the item.

## Sources

1. https://support.apple.com/guide/iphone/edit-and-organize-a-list-iph82596cb20/ios
2. https://support.apple.com/guide/iphone/use-smart-lists-iphe882772ed/ios
3. https://support.apple.com/en-us/102484
4. https://apps.apple.com/us/app/reminders/id1108187841
5. https://macmost.com/reminders-list-sections-and-column-view.html
6. https://culturedcode.com/things/support/articles/4001304/
7. https://culturedcode.com/things/support/articles/2803579/
8. https://culturedcode.com/things/support/articles/9780167/
9. https://culturedcode.com/things/support/articles/2803582/
10. https://culturedcode.com/things/support/articles/2803577/
11. https://www.todoist.com/help/articles/plan-your-week-with-the-upcoming-view-OKOg1mR8
12. https://www.todoist.com/help/articles/introduction-to-dates-and-time-q7VobO
13. https://www.todoist.com/help/articles/how-to-change-your-swipe-actions-D5DQOQz6
14. https://support.apple.com/guide/iphone/iph376ef8aa3/ios
15. https://github.com/grocy/grocy-docs/blob/master/tutorials/food.md
16. https://grocy.info/changelog
17. https://support.apple.com/guide/iphone/intro-to-home-iph22d98bbca/ios
18. https://www.macrumors.com/how-to/reorganize-home-view-home-app/
19. https://support.apple.com/guide/iphone/organize-in-folders-ipha61270292/ios
20. https://support.atlassian.com/trello/docs/add-and-customize-cards-and-lists/
21. https://help.sortly.com/hc/en-us/articles/360036515592-Sortly-Product-Overview
22. https://help.sortly.com/hc/en-us/articles/6660883031451-Sortly-Mobile-App
23. https://help.sortly.com/hc/en-us/articles/360016384492-Bulk-Edit-Items-and-Folders
24. https://apps.apple.com/us/app/nowaste-food-inventory-list/id926211004
25. https://www.nowasteapp.com/
26. https://cozzo.app/features/food-home-supplies-inventory/
27. https://cozzo.app/
28. https://pantrycheck.com/kb/overview/
29. https://apps.apple.com/gb/app/fridgely/id988016972 · https://fridgelyapp.com/
30. https://support.apple.com/guide/iphone/modify-files-and-folders-iphc61044c11/ios
31. https://developer.apple.com/design/human-interface-guidelines/lists-and-tables · https://codershigh.github.io/guidelines/ios/human-interface-guidelines/ui-views/tables/index.html
32. https://flexibits.com/fantastical-ios/help/adding-events-and-tasks

_Method note: Apple's iPhone User Guide pages render client-side, so [1] and [2] were read through their search summaries and [3]/[4]/[5]; [18] stands in for [17]'s body. Pattern galleries (Mobbin's empty-state and date-picker glossaries) returned 403 and are not cited._
