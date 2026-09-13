# Screen scores — working notes (orchestrator, 2026-09-12)

Scale per principle 1–5 (Purpose · Agency · Responsibility · Familiarity · Flexibility · Simplicity · Craft · Delight), total /40.
Rules = the thirteen in docs/research/hig-2026-for-ambry.md §"What a screen scorer must check". Hard checks: 44pt targets, 4.5:1, AX5, states, copy (§7: no "we").

## welcome — 35/40  (P5 A5 R5 Fa5 Fl4 S4 C4 D3)
Clear thesis (icon, name, tagline), three value props with tinted glyphs, one prominent primary ("Get started") and a plain secondary. Familiar, minimal. Findings: large dead band between the tagline and the props (Craft); secondary "I already have an account" is plain text — fine, but its hit height should be ≥44 (check); no motion or product image, so Delight is modest. AX5: "Get started" stays reachable (captured).
Changes: tighten the vertical rhythm (props start ~1/3 down, not 45%); consider a 1-line social proof or a single product frame under the tagline — optional.

## sign-in — 34/40  (P5 A5 R5 Fa5 Fl3 S5 C4 D2)
Correct SIWA button style (black), Google white, "or use email" divider, disabled grey primary, two green text links. Findings: the screen is a KeyboardAvoidingView with no scroll, so at AX5 the submit button is below the fold (tour: ax5 gap) — Flexibility; the Google label runs off the edge mid-word at AX5 (agent finding); "Sign in" is both the heading and the button (fine for a person, tricky for automation — already handled by testID).
Changes: make the form scroll (ScrollView + keyboard inset) so submit is always reachable; let social buttons wrap/shrink at AX sizes.

## sign-up — 35/40  (P5 A5 R5 Fa5 Fl3 S5 C4 D3)
Same shape plus a subtitle that sets expectations ("Free to start…") and a password hint in the placeholder (HIG: say the rule up front). Findings: same AX5 fold problem; "Display name" first is right (identity before credentials).
Changes: same scroll fix; keep.

## forgot-password — 30/40  (P5 A4 R5 Fa5 Fl3 S5 C3 D0→2)
Findings: copy uses "we'll send a link" — HIG §7: never "we" in UI copy ("Enter your account email. A link to set a new password will be sent to it."); no confirmation state visible here (what does the person see after tapping? verify: success state must say where to look); disabled primary until valid — good.
Changes: rewrite the copy without "we"; confirm a sent state that names the address and offers "Back to sign in".

## pantry-index — 31/40  (P5 A4 R5 Fa4 Fl3 S3 C4 D3)
Large title (app-drawn, does not collapse on scroll — rule 2), inline search (household-wide scope: rule 5 says arguably toolbar-worthy), "Expiring Soon 4 >", 2-column location cards with emoji + count, "+ Add location", the THIS MONTH scorecard card. Findings: three cards leave an orphan cell (acceptable for a dynamic grid but the third row's empty half reads unfinished); the scorecard's "100%" big-number tile is the point only when there is data — when nothing went off it is a large card saying nothing; the "foods" unit in a smaller weight next to the count is good; tab bar is app-drawn with frozen tints (rule 4, palette-level); AX5: the Pantry card clips its own label ("Pantr / y" — agent finding) and cards fall below the fold.
Changes: (a) collapse the large title on scroll or move the search into a toolbar search; (b) make location cards a single column at AX sizes and let the label wrap; (c) fold the scorecard into a compact row when the month has nothing to report; (d) tab palette → dynamic colors (one palette finding for all tabs).

## pantry-search — 32/40  (P5 A4 R5 Fa4 Fl4 S3 C4 D3)
Results grouped by location with count headers, clear (x) present, rows: emoji, name, "added Sep 6", two chips. Findings: "2d overdue" next to "Stocked" reads contradictory at a glance — two chips of different kinds (freshness vs stock) with equal weight; row idiom differs from Expiring's (rule 10 / S3 family); keyboard covers the tab bar (expected).
Changes: one status chip per row; freshness as a colored leading edge or a secondary line, not a second pill; unify the row family (S3).

## expiring — 33/40  (P5 A4 R5 Fa4 Fl3 S3 C4 D5)
Custom header with back + one tinted "Add all" (≤1 tinted control ✓), large title with inline count, a green "See what you can make with these" banner-button (purposeful), sections Overdue/Today/In 7 days with red/amber chips and per-row red trash. Findings: a destructive trash on every row invites accidental taps (undo exists — verify the toast); the section header "Overdue" in red carries meaning by color plus text ✓; the header title and the "4 items this week" subtitle sit on different baselines (Craft); large title does not collapse (rule 2).
Changes: swipe-to-delete with the trash as the revealed action (HIG list idiom), keeping an onscreen path via the row's overflow; align the subtitle; consider "Add all" → "Add all to list" (verb + object).

## insights — 26/40  (P3 A3 R5 Fa4 Fl4 S4 C3 D2)
"This month" native-looking header; one card ("100% used up · 5 eaten · 0 went off") and the sentence "Nothing went off this month." Findings: a whole screen for one number with no next action (HIG §5 empty/near-empty state: guide the next action); unreachable through the UI until five outcomes exist (agent finding) — the Pantry card that links here shows the same number, so the screen adds nothing today; the earlier build showed "Not enough this month to say anything useful yet." with no control.
Changes: either make Insights earn the screen (a month-over-month chart, the foods that went off most, what to buy less of — the waste scorecard's purpose in spec) or fold it into the Pantry card and drop the route; in both cases give the empty state a next action ("Log what you finish from Expiring").

## location-fridge — 31/40  (P5 A4 R5 Fa4 Fl3 S3 C4 D3)
Native-looking header (emoji + name, overflow "…"), a dismissable explainer banner, a local search pill, a four-segment filter plus a separate "Select" text action, category sections with counts, rows with emoji, "added" date, days-left and a status chip. Findings: the banner is in-content help that competes with the list and fills the AX5 viewport (agent finding; HIG: help belongs where it is needed and never blocks the task); "Select" is a toolbar action living inside content next to a segmented control (mixed idioms); "15d" / "no est." are unlabelled abbreviations; the row family differs from Pantry search and Expiring (S3, rule 10).
Changes: move the explainer to a one-time tip or the overflow ("About struck-through items"); put Select in the header overflow or an Edit button; label the days ("15 d left" or a secondary line); unify the row family.

## location-zones — 27/40  (P4 A4 R5 Fa3 Fl3 S3 C3 D2)
Three icon buttons per row (rename, red trash, drag handle), a paragraph of explanation, an add field with a disabled Add. Findings: per-row icon triplet under the 44pt default and three ways to act on one row; red trash on every row; rename via pencil rather than tap-to-edit; the paragraph is long (HIG: if a control needs a lot of text, simplify).
Changes: standard editable list — tap the name to rename inline, swipe to delete (with an overflow path), an Edit button for reordering; one sentence of help at most.

## item — 31/40  (P5 A4 R5 Fa4 Fl3 S3 C4 D3)
Hero card (emoji, name, category · added), STORAGE group (Location, Zone, Status segmented), EXPIRY (date + "estimated from shelf life", +3d/+1w/+2w/+1m chips, "Type a date", "Clear date"), NOTES, then a Nutrition Facts-style label. Findings: the header bar is empty except the back chevron — no title collapses in (rule 2 analogue); the item name is set in muted grey, which reads as a placeholder although it is the primary identity (or, if it is an editable field, it does not look editable — S11's two save models); "Clear date" as a bare green link; the nutrition label's typographic style is a genuine, distinctive detail (keep).
Changes: name in ink weight, with an explicit edit affordance if it is editable; title in the bar on scroll; group "Type a date / Clear date" as one row with a trailing menu.

## lists — 32/40  (P5 A5 R5 Fa4 Fl3 S3 C4 D3)
Large title, an add field, TO BUY with checkboxes, IN YOUR CART with strike-through and an overflow at the section header, a black "Restock 1 to Kitchen" primary inside the scroll, SUGGESTED with "Out" chips and a green + per row. Findings: the primary action scrolls away with the content (HIG: prioritise the main-task action — a bar or a sticky footer above the tab bar); the add field is a text field where the other tabs use a search pill (inconsistent input family); the title sits outside the scroll view so the space is never recovered (rule 2, flagged harder); three-dot "..." placeholder. Recapture 12:48: unchanged; the green ⋯ overflow on the IN YOUR CART header is a 24 pt glyph at the section edge, below the 44 pt target unless its hit area is padded. At the largest text size (13:01 shot) the section count "4" and that overflow glyph overlap, and "Sourdough" breaks mid-word ("Sourdoug / h") because the row's text column does not shrink the thumbnail — two concrete AX5 defects on this screen.
Changes: sticky restock action; one input style across tabs; collapsing title.

## grocery-restock — 32/40  (P5 A4 R5 Fa4 Fl3 S4 C4 D3)
"1 bought item", a "Put everything in…" chip that opens a picker, a per-item card with location and expiry chips, a black primary. Findings: the chip's affordance is ambiguous (it is a picker); the primary sits in content (fine at one item, scrolls away at many); AX5 not captured (below the fold on Lists).
Changes: make the picker a menu-styled button ("Put everything in ▾"); sticky primary when the list is long.

## add — 34/40  (P5 A5 R5 Fa5 Fl4 S4 C4 D3)
Large title, search pill, a two-row card (Scan barcode / Snap groceries or receipt) with tinted glyphs, RECENT with one-tap +. Findings: the active tab tint here is orange where Pantry's was green — the tab bar carries a per-tab tint (rule 4: one tint per bar, dynamic colors); otherwise the three entry points are exactly right.
Changes: one tab tint; nothing else.

## add-search — 34/40  (P5 A5 R5 Fa5 Fl4 S4 C4 D3)
Results with location and a shelf-life hint ("Fridge · ~7 days") and a + per row; clear button present. Findings: the hint appears only on some rows (fine — where known); keyboard covers the tab bar (expected).
Changes: none beyond the tab tint.

## add-scan — 33/40  (P5 A4 R5 Fa4 Fl3 S4 C4 D4)
Full-height camera viewport with a rounded frame, torch, guidance text, "Enter number instead", a staging line and a disabled Review. Findings: a pushed screen with a header rather than a full-screen modal (HIG prefers full-screen for camera tasks, but the push keeps the back path — acceptable); the torch glyph inside the viewport is small (check 44pt); the staging line "Scan products — they stage here" is good copy.
Changes: check the torch target; consider a sheet-style dismiss (X) since scanning is a task, not a place.

## add-receipt — 33/40  (P5 A4 R5 Fa4 Fl3 S4 C4 D4)
Camera viewport with a Receipt/Groceries segmented overlay, shutter, gallery and document glyphs, and a quota line ("10 of 10 AI scans left this month"). Findings: quota disclosure up front is exactly right (Responsibility); the segmented overlay inside the viewport is custom but legible; same push-vs-full-screen note as scan.
Changes: none blocking; consider the same dismiss treatment as scan.

## capture-review — 32/40  (P5 A4 R5 Fa4 Fl3 S4 C4 D3)
"1 item staged" with a red Clear, the "Put everything in…" picker chip, a per-item card (name, location chip, "no expiry estimate" chip, chevron), a black primary. Findings: long product names truncate to one line (allow two); the picker chip's affordance (same as restock); the family matches restock — good consistency.
Changes: two-line names; menu-styled picker.

## recipes-cook — 31/40  (P5 A4 R5 Fa4 Fl3 S3 C4 D4)
Large title, a three-segment sub-navigation (Cook / My recipes / Community), a black "✨ Ask for ideas for your 4 expiring items" primary, an orange sentence, YOU CAN MAKE / ALMOST THERE cards with missing-ingredient chips. Findings: an emoji as the primary's glyph (HIG: symbols, not emoji, in controls); every card carries the same placeholder thumbnail — dead weight that makes the list look unfinished; the orange sentence is emphasis by color with text (fine); the Recipes tab tint is purple (per-tab tint, rule 4).
Changes: SF Symbol on the primary; drop the placeholder thumbnail (or use a category glyph) until a photo exists; one tab tint.

## recipes-mine — 31/40  (P5 A5 R5 Fa3 Fl3 S3 C4 D3)
"My recipes" with a sort glyph and a black "+ Add recipe" button in content, a Folders row, a list with time and visibility chips. Findings: a second black primary in the same tab (the Cook segment has "Ask for ideas") — HIG: one or two prominent buttons per view; "+ Add recipe" belongs in the bar as a "+"; Household and Public chips share one green (text distinguishes them, colour does not — acceptable but wasteful); placeholder thumbnails again.
Changes: "+" in the header, one prominent action per view; thumbnails as above.

## recipes-community — 28/40  (P5 A4 R5 Fa3 Fl3 S3 C3 D3)
A bordered text field "Search public recipes...", filter and sort glyph buttons, cards with big placeholder thumbnails and a green byline. Findings: the search input bypasses the shared SearchField (`CommunityList.tsx:88` — HIG record rule 5, confirmed on screen: it is a text field where every other tab has a search pill); the empty thumbnails dominate the card; no ratings or follow affordance in the list (following UI from #220 not in this build — recapture pending); three-dot placeholder. Recapture 12:53 against main with #220: a new All / Following chip row sits between the segment and the search field, so the list now has three control rows before the first recipe; the chips are styled as a solid black selection (fill + label ✓) but they are a second filter idiom on a screen that already has a filter button (sliders glyph) beside the search field. Dark mode: the search field is a bordered dark-grey box, still not the search pill; the green byline reads fine.
Changes: adopt SearchField; card = title, byline, time, rating, and a photo only when there is one; a Follow affordance on the byline once #220's recapture confirms its placement.

## recipe-detail — 29/40  (P5 A4 R5 Fa4 Fl3 S3 C3 D3)
Title bar with three trailing glyphs (heart, folder, pencil), title, "Serves 2 · 25 min · Public", stars, description, INGREDIENTS with ✓/○ per row (colour plus shape ✓) and a chain-link glyph on every row, STEPS, an estimated Nutrition label. Findings: **Start cooking is not on the first screen** — the recipe's main-task action sits below the comments (research `index.tsx:553-579`; HIG toolbars: prioritise the main-task action); a link glyph repeated on every ingredient row is noise (make it a row action revealed on tap or a single "Link ingredients" affordance); the parsed amount shows through ("4, chopped Tomatoes"); three trailing bar actions where the research suggests heart + overflow. Recapture 12:53 with #219/#220: the header bar now carries three glyph actions (favorite, folder, edit) with no labels; the missing ingredient is a hollow orange ring against green checks (color plus shape ✓); the ingredient rows each show a green link glyph on the trailing edge whose meaning is unstated. Dark mode matches light.
Changes: Start cooking between Ingredients and Steps (and as the bar's prominent action); one link affordance; heart + overflow in the bar; time/servings directly above the ingredients.

## recipe-cook-mode — 33/40  (P5 A4 R5 Fa4 Fl4 S5 C4 D3)
"0 OF 1 DONE", one large step card with a radio, "Done cooking" primary. Findings: clean and legible at cooking distance; no ingredient list at hand (research notes it as a deferred item); with one step the screen is mostly empty.
Changes: an ingredients disclosure at the top; keep the rest.

## recipe-edit — 24/40  (P4 A3 R5 Fa3 Fl3 S2 C2 D2)
TITLE, a dashed PHOTO box, SERVINGS, TIME (h/min + Clear), DIFFICULTY slider with a two-sentence explanation and a computed minimum, TAGS with a black "Choose tags..." button and an "Or add your own..." field — and no Save in sight. Findings: the order asks for metadata before the recipe (research: ten sections precede Save at `RecipeForm.tsx:419-614`); explanatory copy under nearly every field (HIG: if a control needs a lot of text, simplify); a black primary used for a secondary action mid-form (HIG: one or two prominent buttons per view); the difficulty slider's rule ("At least 2 for a recipe with 5 ingredients") is a constraint expressed as prose; Save is not reachable without scrolling to the end; uncommitted tag text is discarded on save (research defect 1).
Changes: this is the recipe program's spec (AMBR-41): title → ingredients → steps first, Save persistent in the bar, everything else behind "More"; paste into rows; commit or warn on pending input. Not a screen-review change — a build.
