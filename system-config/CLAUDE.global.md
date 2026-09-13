## Workspace protocol

`~/agents` is an ICM staged workspace whose knowledge layer is an OKF bundle
(`~/agents/SPEC.md`). When working there, read `~/agents/CLAUDE.md` (Layer 0 —
where you are) then `~/agents/CONTEXT.md` (Layer 1 — where to go). Load only
what the stage you are in asks for; do not read the whole workspace.

Sessions on the mini that touch the Multica board, an AMBR-n, a board agent or squad, or a
PR from the loop load the `orchestrator` skill first — it is the operating procedure.

## Shared memory

`~/agents/memory/` is an OKF bundle: one concept per file, YAML frontmatter,
cross-linked, `index.md` at every level.

- **Before any task**: open `~/agents/memory/index.md` and follow links down —
  `projects/` for current state, `decisions/` for why, `entities/` for a
  machine/repo/service, `sources/` for an external spec we have read. Load only
  the matching concepts. Grep is the fallback, not the entry point.
- **Stable operating rules** are Layer 3 in `~/agents/references/` —
  `safety-rules.md` before any production action.
- **After any task**: append a handoff note to
  `~/agents/memory/daily-log/$(date +%F).md` covering what was done, decisions
  made, and open items.
- **A durable fact gets its own concept file** — not a paragraph appended to the
  nearest note. Give it frontmatter (`type` is required and must be
  informative), link it from the enclosing `index.md`, then:
  `python3 ~/agents/scripts/okf-check.py` must exit 0.

Full protocol: the `memory-protocol` skill.

## Spec-first, think-first
- Think deeply before implementing anything. Lay out the goal, constraints,
  options considered, and edge cases before touching code — never jump straight
  to implementation.
- Before building any new functionality (feature, screen, endpoint, workflow,
  integration), write a detailed spec file FIRST and keep it in the repo:
  - whole project → SPEC.md at the repo root (goals, domain model, features,
    data model, milestones, open questions)
  - individual feature → specs/<feature>.md (purpose, UX flows, data/schema
    changes, edge cases, error and empty states, acceptance criteria)
- Show the user the spec and get their sign-off before implementing when scope
  is new or requirements are ambiguous; for small additions inside an
  already-agreed spec, update the spec in the same PR as the code.
- Specs are the source of truth: whenever behavior changes, update the spec in
  the same change. Pure bug fixes and refactors that don't change behavior need
  no new spec.

<!-- CODEGRAPH_START -->
## CodeGraph

In repositories indexed by CodeGraph (a `.codegraph/` directory exists at the repo root), reach for it BEFORE grep/find or reading files when you need to understand or locate code:

- **MCP tool** (when available): `codegraph_explore` answers most code questions in one call — the relevant symbols' verbatim source plus the call paths between them, including dynamic-dispatch hops grep can't follow. Name a file or symbol in the query to read its current line-numbered source. If it's listed but deferred, load it by name via tool search.
- **Shell** (always works): `codegraph explore "<symbol names or question>"` prints the same output.

If there is no `.codegraph/` directory, skip CodeGraph entirely — indexing is the user's decision.
<!-- CODEGRAPH_END -->
