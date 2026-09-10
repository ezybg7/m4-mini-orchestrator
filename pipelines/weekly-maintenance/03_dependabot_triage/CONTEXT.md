---
type: stage
title: 03_dependabot_triage
description: Merge, close, escalate or skip each Dependabot PR by policy.
tags: [pantry, security, infra]
timestamp: 2026-09-10T00:00:00Z
---

# 03_dependabot_triage

## Inputs
- Layer 4 (working): open Dependabot PRs and their CI status
- Layer 3 (reference): the repo's own `.github/dependabot.yml` — **read it first**
- Layer 3 (reference): [Safety rules](../../../references/safety-rules.md)

Two facts from that config shape everything: bumps are **grouped**
(`app-routine` for `/`, `worker-routine` for `/workers`, plus github-actions), so
a PR is judged **by its worst member**; and the Expo-pinned set plus TypeScript
are already `ignore`d, so an expo-shaped PR is a **signal, not noise**.

## Process

| Situation | Action |
|---|---|
| Routine bump to `expo`, `expo-*`, `@expo/*`, `react-native*`, `react`, `react-dom`, `jest-expo`, TypeScript | **Close** + comment (SDK-pinned / one unified TS major) |
| **Security advisory** on that same set | **Escalate** — never merged, never closed. The fix goes through `npx expo install` or an SDK upgrade: a human's call |
| CI fully green **and** every package patch/minor, or a security fix at any level | **Merge** (squash) |
| CI red, CI pending, any major in the set, anything uncertain | **Skip** + comment saying why |

"CI green" is the whole gate set — `ci.yml` runs root typecheck, workers
typecheck, lint and jest. Never re-run them locally.

**Never `npm audit fix --force`.** It downgrades expo.

## Outputs
- Merged / closed / commented PRs; one summary line for stage 4.

## Verify
Every PR got exactly one action, and every close or skip carries a comment saying
why. An untouched PR is a bug in this stage, not a neutral outcome.
