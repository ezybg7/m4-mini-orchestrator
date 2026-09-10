---
type: index
title: AGENTS.md — shared entry point
description: The same Layer 0 door for agent runtimes that read AGENTS.md rather than CLAUDE.md.
tags: [protocol, index, tooling]
timestamp: 2026-09-10T00:00:00Z
---

# AGENTS.md — shared entry point

Any agent runtime that reads `AGENTS.md` rather than `CLAUDE.md` starts here.
Both files describe the same workspace; neither is authoritative over the other.

**Read [`CLAUDE.md`](CLAUDE.md) (Layer 0 — where you are), then
[`CONTEXT.md`](CONTEXT.md) (Layer 1 — where to go).** They are plain markdown
and carry no Claude-specific instructions.

This workspace follows [`SPEC.md`](SPEC.md): an ICM staged workspace
(arXiv:2603.16021) over an OKF knowledge bundle. In short:

- Durable knowledge is `memory/` — one concept per file, YAML frontmatter,
  cross-linked, `index.md` at every level. Enter at `memory/index.md`.
- Stable operating rules are `references/`. Read `references/safety-rules.md`
  before any production action.
- Recurring work has a stage contract under `pipelines/`. Load what its
  `## Inputs` names — not the whole workspace.
- One-off work goes in `runs/<YYYY-MM-DD>-<slug>/`.

Before writing a concept, read [`references/tool-harmony.md`](references/tool-harmony.md):
several tools read and write these files, and the contract between them is short
but load-bearing.
