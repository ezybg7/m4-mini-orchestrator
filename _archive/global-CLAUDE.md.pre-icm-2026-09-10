## Shared memory
Before any task: read relevant files in ~/agents/memory/ (grep by project name).
After any task: append a handoff note to ~/agents/memory/daily-log/$(date +%F).md covering what was done, decisions made, and open items.

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
