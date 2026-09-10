---
type: spec
title: Orchestrator Workspace Protocol
description: How ~/agents is structured — an ICM staged workspace whose knowledge layer is an OKF bundle.
resource: https://github.com/ezybg7/m4-mini-orchestrator
tags: [protocol, okf, icm, workspace, memory]
timestamp: 2026-09-10T00:00:00Z
---

# Orchestrator Workspace Protocol

`~/agents` is the M4 mini's orchestrator workspace. This spec defines how it is
structured and is the source of truth for that structure. It adopts two external
specifications wholesale:

- **OKF** — Open Knowledge Format v0.1 (Google Cloud, 2026-06-12). Governs the
  **knowledge** layer: how durable facts are represented on disk.
  <https://cloud.google.com/blog/products/data-analytics/how-the-open-knowledge-format-can-improve-data-sharing>
- **ICM** — Interpretable Context Methodology (Van Clief & McDermott,
  arXiv:2603.16021v2). Governs the **workflow** layer: how context is delivered
  to an agent across a multi-step task. <https://arxiv.org/abs/2603.16021>

They are complementary and non-overlapping. OKF says what a knowledge file looks
like. ICM says which files an agent loads, when, and in what order.

> Naming note: the arXiv abstract page calls the method "Model Workspace
> Protocol (MWP)"; the v2 full text calls it "Interpretable Context Methodology
> (ICM)". Same method. This spec uses ICM, matching the paper body.

## 1. Goals

1. An agent starting cold in `~/agents` knows where it is, where to go, and what
   rules apply — without grepping and guessing.
2. Every durable fact lives in exactly one file, with queryable frontmatter, and
   is reachable by following links from an index.
3. Every recurring workflow is a numbered folder of stage contracts, not tribal
   knowledge in a shell script or a person's head.
4. Every intermediate artifact is a plain file a human can open, edit, and hand
   back to the next stage.
5. The workspace stays copyable: `git clone` (or a tarball) is the whole system.

## 2. Adopted principles

### 2.1 OKF — the knowledge layer (9 rules)

| # | Rule | Enforcement |
|---|------|-------------|
| O1 | Knowledge is a directory of markdown files. No database, no SDK, no proprietary format. | `okf-check.py` |
| O2 | One concept per file. The file path **is** the concept's identity. | review |
| O3 | YAML frontmatter carries the structured fields. `type` is the **only** required field. Conventional: `title`, `description`, `resource`, `tags`, `timestamp`. | `okf-check.py` |
| O4 | Concepts cross-link with ordinary markdown links, making the directory a graph richer than the folder tree. | `okf-check.py` (orphan warn) |
| O5 | `index.md` at every level, for progressive disclosure as an agent navigates down. | `okf-check.py` |
| O6 | `log.md` carries chronological history, separate from current state. | convention |
| O7 | Minimally opinionated: this spec defines the interoperability surface, not the content model. Body structure is the author's business. | — |
| O8 | Producer/consumer independence. Anything may write the vault; anything may read it. The format is the contract. | ≥2 live consumers |
| O9 | Format, not platform. Version-controlled beside what it describes; human-readable and agent-parseable — same file, no translation layer. | — |

### 2.2 ICM — the workflow layer (5 principles + architecture)

| # | Principle | What it means here |
|---|-----------|--------------------|
| I1 | **One stage, one job** | A stage that rehearses a migration does not also apply it. |
| I2 | **Plain text as the interface** | Stages hand off through markdown and JSON on disk. Nothing else. |
| I3 | **Layered context loading** | Load only the current stage's context. Prevention, not compression. |
| I4 | **Every output is an edit surface** | Each stage writes to `output/`; a human may edit it before the next stage reads it. |
| I5 | **Configure the factory, not the product** | Stable rules live in `references/` and are set once; per-run artifacts live in `output/` and change every run. |

Supporting architecture, also adopted:

- **I6 — Numbered folders encode execution order.** `01_`, `02_`, `03_`.
- **I7 — Stage contract = `## Inputs` / `## Process` / `## Outputs`**, plus the
  paper's proposed **`## Verify`** section for cross-stage consistency checks
  (§6.2). Inputs are listed one per line and tagged `Layer 3` or `Layer 4`.
- **I8 — The workspace is a folder**: portable, git-versioned, diffable.
- **I9 — Observability is a side effect**, not a feature. No dashboard; open the
  folder and read the files.
- **I10 — Edit the source, not the output.** A correction made three runs in a
  row is a defect in a stage contract or a reference file. Fix it there.
- **I11 — Respect the boundaries.** ICM is for workflows that are *sequential,
  reviewable, repeatable*. It is explicitly the wrong tool for real-time
  multi-agent collaboration, high-concurrency serving, and automated mid-pipeline
  branching. Those stay in code.

### 2.3 The five-layer context hierarchy

| Layer | File | Question | Budget |
|-------|------|----------|--------|
| 0 | `~/agents/CLAUDE.md` | Where am I? | ~800 tok |
| 1 | `~/agents/CONTEXT.md` | Where do I go? | ~300 tok |
| 2 | `pipelines/<name>/<NN_stage>/CONTEXT.md` | What do I do? | 200–500 tok |
| 3 | `references/**`, `memory/**` | What rules apply? (the factory — stable) | 500–2k tok |
| 4 | `runs/**`, `<stage>/output/**` | What am I working with? (the product — per-run) | varies |

`~/.claude/CLAUDE.md` sits above Layer 0 as the machine-wide preamble and is not
part of this workspace.

## 3. Domain model

Two kinds of thing, kept structurally apart because they ask different things of
the model — Layer 3 is *internalized as constraints*, Layer 4 is *processed as
input* (ICM Table 2).

- **Concept** (OKF) — a durable fact. One markdown file with frontmatter, under
  `memory/` or `references/`. Stable across runs. Layer 3.
- **Artifact** (ICM) — the output of one stage of one run. A file under a stage's
  `output/` or under `runs/`. Disposable, per-run. Layer 4.

Concept `type` vocabulary (OKF O7 leaves this to the producer; this is ours):

`index` · `project` · `decision` · `entity` · `reference` · `runbook` · `plan` ·
`log` · `spec` · `stage`

## 4. Target structure

```
~/agents/
├── CLAUDE.md              Layer 0 — identity
├── CONTEXT.md             Layer 1 — routing table
├── SPEC.md                this file
├── references/            Layer 3 — the factory (stable rules)
│   ├── index.md
│   ├── machines.md        extracted from projects/pantry.md
│   ├── safety-rules.md    never-do list, escalation, secret handling
│   └── conventions.md     git/PR, spec-first, model roles
├── memory/                Layer 3 — OKF bundle (durable knowledge)
│   ├── index.md
│   ├── projects/index.md + <project>.md
│   ├── decisions/index.md + <decision>.md
│   ├── entities/index.md  + <entity>.md
│   └── daily-log/index.md + <date>.md + archive/
├── pipelines/             Layer 2 — stage contracts
│   ├── index.md
│   ├── nightly-reflection/{CONTEXT.md, 01_survey…04_report}
│   ├── db-apply/{CONTEXT.md, 01_rehearse…04_verify}
│   └── weekly-maintenance/{CONTEXT.md, 01_…}
├── runs/                  Layer 4 — per-run working artifacts
├── scripts/               mechanical work that needs no AI (ICM §1)
├── queue/, logs/, skills/ load-bearing, unchanged
└── _archive/              superseded files, kept for history
```

Deviation from ICM, recorded deliberately: the paper puts `stages/` directly in
the workspace because a workspace is one pipeline. We run several, so a pipeline
is `pipelines/<name>/` and its `CONTEXT.md` is that pipeline's Layer 1. Each
pipeline folder remains independently copyable, which is the property the paper
actually cares about (§3.4).

## 5. Constraints

Load-bearing paths that **must not move** — cron, launchd, and hardcoded
references depend on them:

- `~/agents/queue/` — watched by launchd `com.user.claude-worker`
- `~/agents/scripts/{backup,watchdog,nightly-reflection,claude-worker}.sh` — cron
- `~/agents/memory/` — named in `~/.claude/CLAUDE.md`, `queue/.preamble.md`, the
  `memory-protocol` skill, and indexed by the `basic-memory` MCP server
- `~/agents/logs/` — cron writes here
- `~/agents/skills/` — symlinked as `~/.claude/skills`

`memory/` frontmatter must stay readable by **basic-memory** (it owns `title` and
`permalink`). Those two fields are preserved untouched; OKF fields are added
alongside. This is OKF O8 in practice: basic-memory, grep, and Claude are three
independent consumers of one bundle.

## 6. Milestones

- **M1** Layer 0 + Layer 1 + this spec
- **M2** OKF conformance across `memory/` — frontmatter, indexes, cross-links
- **M3** Split the `pantry.md` mega-note into concepts; extract Layer 3 references
- **M4** `pipelines/` with stage contracts for the three recurring workflows
- **M5** Clean the root into `_archive/` and `runs/`
- **M6** Rewire entry points (`~/.claude/CLAUDE.md`, `queue/.preamble.md`,
  `memory-protocol`) onto the protocol; verify basic-memory still reads the vault
- **M7** `scripts/okf-check.py` — an independent consumer that validates
  conformance (O8, and the enforcement column of §2.1)
- **M8** Commit, push, handoff note

## 7. Acceptance criteria

1. `scripts/okf-check.py` exits 0 over `memory/` and `references/`.
2. Every `memory/**.md` and `references/**.md` has a `type`, and no `type` is the
   uninformative `note`.
3. Every directory under `memory/` and `references/` has an `index.md` that links
   to every file in it.
4. Zero orphans: every concept is reachable by following markdown links from
   `memory/index.md`.
5. Every stage folder has a `CONTEXT.md` with `## Inputs`, `## Process`,
   `## Outputs`; inputs are tagged `Layer 3` or `Layer 4`.
6. `~/agents` root holds only directories plus `CLAUDE.md`, `CONTEXT.md`,
   `SPEC.md`, `.gitignore`.
7. `crontab -l` still resolves every path it names.
8. basic-memory can still read a normalized note.

## 8. Tool integration

There is no integration layer, by design. Tools cooperate because they share a
directory of markdown files with frontmatter — OKF O8 (producer/consumer
independence) is the whole mechanism. The register of who reads what, who owns
which field, and the four rules that keep them from fighting is
[`references/tool-harmony.md`](references/tool-harmony.md).

| Tool | State |
|------|-------|
| Claude Code | integrated — enters at Layer 0 |
| basic-memory | integrated — second producer; conflict resolved (see §9.4) |
| `okf-*` tools | integrated — the checker gates every commit |
| Obsidian | **content-ready**; `.obsidian/app.json` committed. Open `~/agents` as the vault. Not yet pointed there — its only vault is `~/.hermes`. |
| CodeGraph | **scoped, deliberately separate** — indexes code, not this bundle. `~/agents` is not indexed and should not be. |
| Codex | **validated** — sandbox gate 14/14. Reads its own `AGENTS.md` **in the repo**, and cannot read `~/agents` at all (denied by design). Orchestration contracts: [codex-lanes](pipelines/codex-lanes/CONTEXT.md) |

Adding a tool means teaching it the format, or teaching it nothing if it already
reads markdown. Nothing here may become a required dependency: the bundle stays
readable with `cat`.

## 9. Open questions

1. **Automated branching.** ICM §5.2 says branching on AI decisions mid-pipeline
   is where the approach breaks down. `db-apply` needs exactly one branch —
   rehearsal failed vs. passed. Modelled as a human review gate for now; if it
   ever needs to be automatic, it belongs in `scripts/`, not in a contract.
2. **`type` vocabulary drift.** OKF deliberately leaves the vocabulary open, so
   `okf-check.py` warns on an unknown `type` rather than failing. Revisit if the
   warning becomes noise.
3. **Whether `daily-log/` should become `log.md` per area** (O6) instead of one
   dated file per day for the whole workspace. Deferred: the nightly fold already
   moves dated files into project notes, and changing the filename would break
   `nightly-reflection.sh`.

4. **Frontmatter must be valid YAML.** An unquoted scalar containing `": "` is
   not — and basic-memory, unable to parse such a file, prepends its own block
   rather than merging, which the normalizer then removes, forever.
   `okf-normalize.py` quotes on write and this is settled; recorded here because
   the failure was invisible (0 errors, only warnings) and cost the most time.
