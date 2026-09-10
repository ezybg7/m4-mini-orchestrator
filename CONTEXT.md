# Layer 1 — Routing

You have read [CLAUDE.md](CLAUDE.md). This file answers: **where do I go next?**

## Task routing

| If the task is… | Go to | Then |
|-----------------|-------|------|
| Nightly maintenance / reflection | `pipelines/nightly-reflection/CONTEXT.md` | Run stages in order |
| Applying a database migration | `pipelines/db-apply/CONTEXT.md` | **Never skip a review gate** |
| Weekly Dependabot + secret-expiry pass | `pipelines/weekly-maintenance/CONTEXT.md` | Run stages in order |
| Anything about a project's current state | `memory/index.md` → `projects/` | Load only the matching note |
| "Why did we do it this way?" | `memory/decisions/index.md` | — |
| "What is this machine / repo / service?" | `memory/entities/index.md` | — |
| A one-off task with no pipeline | Load Layer 3 by hand (below), work in `runs/<date>-<slug>/` | Log it |

## Shared resources (Layer 3 — load only what the task needs)

- [`references/machines.md`](references/machines.md) — which box does what, what
  is installed where, how they sync.
- [`references/safety-rules.md`](references/safety-rules.md) — secrets, destructive
  operations, what requires Everett's explicit word. **Read before any production
  action.**
- [`references/conventions.md`](references/conventions.md) — git/PR flow, spec-first
  rule, model roles, session hygiene.
- [`memory/index.md`](memory/index.md) — the OKF knowledge bundle.

## Working rules

- **Before**: grep `memory/` for the project name and load only matching notes.
- **During**: work in `runs/<YYYY-MM-DD>-<slug>/`, not in the workspace root.
- **After**: append a handoff note to `memory/daily-log/<YYYY-MM-DD>.md`, and put
  any durable fact in its own concept file under `memory/` — with frontmatter and
  a link from the enclosing `index.md`.

## If no pipeline fits

Do not invent a folder at the workspace root. Either work in `runs/`, or — if
this is a workflow that will recur and wants human review between steps — add a
pipeline under `pipelines/` following [SPEC.md](SPEC.md) §2.2.
