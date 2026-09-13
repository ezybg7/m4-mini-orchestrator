## recipe-new — 24/40  (P4 A3 R5 Fa3 Fl3 S2 C2 D2)
The same form as Edit with the keyboard up: "Name this recipe" first (right), then PHOTO, SERVINGS (placeholder 4), TIME with a sentence under it. Same findings as recipe-edit; this is the recipe program's build, not a screen tweak.

## recipe-import — 30/40  (P5 A4 R5 Fa4 Fl4 S4 C3 D1)
A link field, a disabled Import, and an honest paragraph about which sites work. Findings: no paste affordance — a URL on the clipboard should be offered automatically (HIG: support paste wherever possible); "screenshot the recipe and scan it instead" names a path without linking to it; three sentences of caveat before the person has done anything.
Changes: detect a clipboard URL and prefill or show a "Paste link" button; make "scan it instead" a button; shorten the caveat to one line with a "Which sites work?" disclosure.

## recipe-folders — 33/40  (P4 A5 R5 Fa5 Fl4 S5 C4 D1)
Native-shaped header with "+" in the bar (the one place the app does this right), a single row. Findings: the empty state (zero folders) is unverified; Delight is nil but the screen is a list.
Changes: an empty state that says what a folder is for, with a control.

## recipe-folder — 33/40  (P4 A5 R5 Fa5 Fl4 S5 C4 D1)
Title + pencil, one recipe row with a visibility chip. Fine.
Changes: none.

## recipe-missing-ingredients — 30/40  (P5 A5 R5 Fa3 Fl4 S4 C3 D1)
An app-drawn dialog ("Missing 1 ingredient — Spinach — Add it to your grocery list?") with three stacked grey pills (Cook anyway / Add to list / Cancel) over the dimmed page; behind it the page's bottom shows YOUR RATING and the black Start cooking. Findings: this is an action sheet's job (choices about an action the person just took) drawn as a custom dialog with non-standard buttons — the system action sheet gives Dynamic Type, Reduce Transparency and VoiceOver for free; the screenshot also proves Start cooking lives at the very bottom, after nutrition and rating.
Changes: use the system action sheet (≤4 buttons incl. Cancel ✓); move Start cooking up (recipe program).

## creator-profile — 31/40  (P4 A4 R5 Fa4 Fl4 S5 C3 D2)
Initial avatar, name, "2 recipes · 0 followers · 0 following", the recipe cards. Findings: own-profile view only (no Follow, correct); no bio; placeholder thumbnails; the stats line is plain text where followers/following will become tappable lists (#220) — recapture pending. Recapture 12:50: unchanged — the counts line is still plain text, so followers / following are not yet tappable lists; Follow on a stranger's profile remains uncapturable in this tour (single test user).
Changes: after the recapture: Follow placement per the recipe research (on the profile), tappable counts.

## profile — 30/40  (P5 A4 R4 Fa4 Fl3 S3 C4 D3)
Large title outside the scroll view, ACCOUNT rows (name, About you with a pencil, View my public profile), a quiet "Your email isn't confirmed yet — Resend link" line, HOUSEHOLD rows with the raw invite code and two glyph buttons on one row, "Share invite link", an explanatory paragraph, BEHAVIOUR toggles with another paragraph, then LEARNED SHELF LIVES below the fold. Findings: the unconfirmed-email state is the most consequential thing on the screen and the least visible (grey text; HIG: make status legible, not decorative); a 16-character hex code as row content; three explanatory paragraphs on one screen; the title never collapses and the space is never recovered (HIG record rule 2, flagged harder for Profile); the pencil glyph next to About you is a decorative icon inside a labelled control (rule 11 family).
Changes: a tinted inline notice for the unconfirmed email with a single "Resend" button; invite code behind "Invite people…" (share sheet) rather than a visible hex; paragraphs → one-line footers; collapsing title.

## profile-household — 31/40  (P5 A5 R5 Fa4 Fl4 S4 C3 D2)
A bottom sheet ("Your households") with an explanation, the household row (✓, pencil), "Create or join another". Findings: the sheet has a decorative grabber, no drag, no detents (rule 6); Done/Cancel pairing absent (dismissal is by tapping outside — verify); otherwise clear.
Changes: real sheet behaviour (swipe to dismiss, accessible grabber) — one fix for every BottomSheet.

## profile-about-you — 29/40  (P5 A4 R5 Fa3 Fl3 S3 C3 D3)
An in-place editor inside the ACCOUNT group: Bio (0/280), three Name / https:// pairs, a small black Save and a Cancel. Findings: six bare fields identified only by placeholders (labels vanish once filled); Save styled as a third size of primary button; editing in place inside a settings group is unusual but coherent with the rest of Profile.
Changes: labelled fields (or a single "Add link" row that grows), Save in the group's header row.

## profile-display-name — 32/40  (P5 A5 R5 Fa4 Fl4 S4 C3 D2)
In-place field with a clear button, Save/Cancel, keyboard with a ✓ return key. Fine.
Changes: none.

## profile-invite (overflow sheet) — 31/40  (P5 A5 R5 Fa3 Fl4 S5 C3 D1)
A bottom sheet with one destructive action ("Regenerate invite code", red) and Cancel. Findings: this is an action sheet's job; the custom sheet forgoes the system one's behaviours (rule 6).
Changes: system action sheet.

## profile-invite-links (sheet) — 31/40  (P5 A5 R5 Fa4 Fl4 S4 C3 D2)
"Share invite link": Uses (1 / 5 / No limit), Expires (1 day / 7 days), an explanation, a black "Create & Share". Findings: selected chips are solid green (fill + text ✓); the copy "Revoke it here to kill it sooner" is colloquial (HIG §7: avoid colloquialisms); decorative grabber (rule 6).
Changes: "Revoke it here to end it sooner"; real sheet behaviour.

## profile-plan (the rest of the Profile page: behaviour · learned shelf lives · members · notifications · plan; shots profile-learned, profile-members, profile-reminders, profile-plan) — 30/40  (P5 A4 R5 Fa4 Fl3 S3 C4 D2)
The rest of the Profile tab: toggles with a footer, LEARNED SHELF LIVES as an explanatory empty state, MEMBERS with an "owner" chip, NOTIFICATIONS (toggle + time), PLAN (Free; AI scans 0 of 10 with a progress bar; "Ambry Plus … Coming soon"), ABOUT, Sign out, a red Delete account, a version footer with the Open Food Facts attribution. Findings: four explanatory paragraphs on one screen (HIG: footers are one line); the learned-shelf-lives empty state explains the mechanism well but is a paragraph where a sentence and a control would do; destructive Delete account in red inside a group ✓; the quota bar is a good honest touch.
Changes: one-line footers with "Learn more" disclosures; keep the rest.
