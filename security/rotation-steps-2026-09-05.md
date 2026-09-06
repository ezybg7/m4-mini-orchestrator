# Rotation and decommission steps — 2026-09-05 (Everett)

Decisions taken: leave `test@pantry.dev` as is; the three `@ambry-test.invalid` residue accounts were deleted from production at 11:48 EDT (rehearsed on the branch first; users 5 → 2, households/items untouched).

## 1. Rotate the Neon `neondb_owner` password (~10 min)
Why: the acceptance branch's direct connection string (same role password as production) sat in the private backup repo for one push (02:30 EDT, commit 026e4e0). Untracked since 11:30; the history still has it.
1. Neon console → project **Pantry** (red-water-68835077) → branch **production** → **Roles** → `neondb_owner` → **Reset password**. Copy the new password from the dialog; it is shown once.
2. Update the mini: `~/agents/.env.acceptance` — replace the password segment in **both** `NEON_DIRECT_URL` and `NEON_BRANCH_DIRECT_URL` (or re-copy each Connect snippet with pooling off, role `neondb_owner`). Keep the file mode 600. The acceptance branch keeps the OLD password until it is reset from parent; it expires tonight (21:42 EDT) anyway.
3. Worker: find which role `NEON_DATABASE_URL` uses. `cd ~/code/pantry/workers && npx wrangler login` (once), then `npx wrangler secret list` shows names only — the value is in your password manager or the Cloudflare dashboard (Workers → pantry-api → Settings → Variables). If it is `neondb_owner`: `npx wrangler secret put NEON_DATABASE_URL` (paste the new **pooler** string) and `npx wrangler deploy`. If it is `service_role`/`authenticator`, nothing to do.
4. Verify: `psql "$NEON_DIRECT_URL" -Atc 'select current_user'` from the mini answers `neondb_owner`; sign in on the dev build and add an item (exercises the Worker → Neon path).
5. Optional but tidy: purge the file from the backup repo's history — `cd ~/agents && git filter-repo --invert-paths --path .env.acceptance --force && git push --force origin main` (install `git-filter-repo` via Homebrew first; the mini's cron backup will keep pushing the cleaned tree). Rotation alone already makes the leaked value worthless.

## 2. Decommission the dead auth and database leftovers (~10 min, console)
1. **Neon Managed Auth**: console → project → **Auth** (the "BetterAuth — Enabled" badge on the overview). Disable it. The app has used its own Better Auth on the Worker (schema `app_auth`) since the 2026-08-22 cutover; the legacy `neon_auth` schema holds 9 empty tables (11 stale session rows) and nothing of ours references it (spec 46 row "Leave, then remove"). After you disable it, tell me — I apply the prepared drop migration (0055) so the schema goes away cleanly and the registry records it.
2. **Supabase project `vetlkzfzvwrqgblaszbq`** (if it still exists): supabase.com dashboard → project settings → General → **Delete project**. Nothing points at it; its publishable key in old commits becomes inert.
3. **GitHub**: nothing to remove — the pantry repo has zero Actions/Dependabot secrets, variables, webhooks or deploy keys; the vault repo is private and no longer tracks env files.

## 3. Left alone on purpose
- `test@pantry.dev` / its documented password: your call today ("leave the test account"). Note it is a live production credential-account whose password is in the repo; revisit before external beta (the release pass keeps the reminder).
- Public identifiers in the repo (Google OAuth client id, Neon endpoint hosts, the Worker URL, Sentry DSN if added): not secrets.
