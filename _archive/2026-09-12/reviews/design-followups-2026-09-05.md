# Design follow-ups surfaced while building the screen mocks (2026-09-05)
- ConfirmSheet's primary CTA on main still fills with `accentFill` (green); design-system rule 2 says filled primaries are ink (`specs/design-system.md`). Visible on the Add tab's confirm sheet. → small P-fix PR (Button variant) after the mocks review.
- Spec 28 (password reset) follow-up from #185's review: the reset mail shares the rotating-IP exposure FIND-001 closed for verification mail (per-address 1/min + ≤5/day ledger) — amend spec 28 to reuse `app_auth.email_sends` for reset sends. Docs PR after #185 merges.
