---
type: reference
title: Interpretable Context Methodology (ICM)
description: Van Clief & McDermott, arXiv 2603.16021 - replacing framework orchestration
  with filesystem structure. Governs this workspace's pipelines.
resource: https://arxiv.org/abs/2603.16021
tags:
- protocol
- workflow
- icm
timestamp: 2026-03-18 00:00:00+00:00
permalink: agents/sources/icm-folder-structure-as-agent-architecture
---

# Interpretable Context Methodology (ICM)

Jake Van Clief and David McDermott (Eduba / University of Edinburgh).
arXiv:2603.16021, v1 2026-03-17, **v2 2026-03-18** — 28 pages, 54 references,
MIT-licensed. Read in full 2026-09-10. Adopted — see [SPEC.md](../../SPEC.md).

> **Naming.** The arXiv *abstract* page calls the method "Model Workspace
> Protocol (MWP)"; the v2 *full text* calls it "Interpretable Context
> Methodology (ICM)". Same method. We use ICM, matching the paper body.

## The claim

For workflows that are **sequential, human-reviewed, and repeatable**,
multi-agent frameworks (CrewAI, LangChain, AutoGen) solve a coordination problem
that need not exist. If the prompts and context for each stage already exist as
files in a well-organized hierarchy, you do not need a framework to coordinate
specialized agents — you need **one agent that reads the right files at the right
moment**. Numbered folders are the stage sequencing. The folder hierarchy is the
context scoping. Files on disk are the state. One folder's output being the next
folder's input is the coordination.

Changing stage order becomes renaming folders; modifying a prompt becomes editing
a markdown file; adding a stage becomes adding a folder; inspecting intermediate
state becomes opening the folder; handing the system to someone else becomes
copying it. Anyone with a text editor can make those changes, not just a developer.

## The five design principles

1. **One stage, one job.** Each stage handles a single step and writes to its own
   folder. A stage that fetches does not also filter.
2. **Plain text as the interface.** Markdown and JSON. No binary formats, no
   database connections, no proprietary serialization.
3. **Layered context loading.** Each stage loads only what it needs — prevention
   rather than compression. Within content, **reference material** (stable rules,
   the *factory*) is kept structurally separate from **working artifacts**
   (per-run content, the *product*), because they ask different things of the
   model: reference should be internalized as constraints, working material
   processed as input.
4. **Every output is an edit surface.** Each stage's output is a file a human can
   open, edit, and save before the next stage runs. The next stage reads whatever
   the human left there.
5. **Configure the factory, not the product.** A workspace is set up once with
   preferences, style, and structural decisions; each run produces a new
   deliverable using that configuration.

## The five-layer hierarchy

| Layer | File | Question | Budget |
|---|---|---|---|
| 0 | `CLAUDE.md` | Where am I? | ~800 tok |
| 1 | `CONTEXT.md` | Where do I go? | ~300 tok |
| 2 | stage `CONTEXT.md` | What do I do? | 200–500 tok |
| 3 | `references/`, `_config/` | What rules apply? (stable) | 500–2k tok |
| 4 | `output/` | What am I working with? (per-run) | varies |

**Layer 2 is the control point of the whole system.** Each stage contract
declares `## Inputs` (which Layer 3 and Layer 4 files to load), `## Process`, and
`## Outputs`. Without that explicit scoping an agent either loads everything or
relies on its own judgment about what matters; the Inputs table makes the
selection explicit, editable, and auditable.

No agent reads everything. A stage typically receives 2,000–8,000 tokens; a
monolithic prompt carrying all stages' instructions and all prior outputs reaches
30,000–50,000, most of it irrelevant — into the range where Liu et al.'s "lost in
the middle" degradation applies. ICM avoids that by construction rather than
compressing after the fact.

## Findings worth keeping

- **U-shaped intervention.** Across 33 practitioners, 30 reported heavy editing
  at stage 1 (direction-setting — creative judgment), light editing in the middle
  (constrained by both an upstream anchor and reference material), heavy again at
  the final stage (alignment work — closer to debugging). Self-reported through
  conversation, not instrumented.
- **Observability is a side effect, not a feature.** Nothing was made
  transparent by adding an explanation layer; it was never opaque, because every
  artifact is a plain file. Rudin's argument for inherently interpretable systems
  applied at the workflow level.
- **Non-developers edit stage behavior successfully** by changing markdown —
  adding constraints, adjusting tone, reordering emphasis — work that would
  otherwise need a developer to change agent configuration.
- **The folder structure does double duty**: it is the human's control surface
  *and* the specification the orchestrating agent uses to decide what context to
  give its sub-agents.

## Edit the source, not the output (§6.3)

Editing a stage's output fixes this run; editing the file that produced it fixes
every future run. In compiler terms, editing output is patching the binary.

Some output edits are legitimately creative — a turn of phrase no voice guide
would have produced. But a **class** of edits is diagnostic: consistently
tightening the opening means the contract should say "keep the opening under
three sentences"; tone drifting formal every time means the reference file needs
a stronger example. Recurring edits are debugging information pointing at
fixable source-level problems.

## Where it explicitly does NOT work (§5.2)

- **Real-time multi-agent collaboration** — tight loops need message-passing
  infrastructure; file handoffs are too slow.
- **High-concurrency systems** — ICM is local-first; many simultaneous users need
  queueing, state isolation, deployment infrastructure.
- **Automated mid-pipeline branching** — a human can branch between stages, but
  automating it moves ICM toward being a framework itself.

The paper is explicit that this is not a general replacement for frameworks. We
record this as rule I11 and honor it: `db-apply`'s one branch is a human gate.

## Threats to validity, as the authors state them

Informal data collection (conversations, not structured interviews or
instrumented logs); an invite-only, self-selected community, so selection and
enthusiasm bias; a single model family (Opus 4.6 / Sonnet 4.6) tested; and **no
controlled comparison** against monolithic prompting — the context-scoping
quality claim rests on the "lost in the middle" literature and practitioner
judgment, not measured effect sizes.

## How we apply it

[SPEC.md](../../SPEC.md) §2.2 as principles I1–I11. Three pipelines exist:
[nightly-reflection](../../pipelines/nightly-reflection/CONTEXT.md),
[db-apply](../../pipelines/db-apply/CONTEXT.md), and
[weekly-maintenance](../../pipelines/weekly-maintenance/CONTEXT.md). We deviate
in one recorded way: the paper puts `stages/` at the workspace root because a
workspace is one pipeline; we run several, so a pipeline is `pipelines/<name>/`.

Related: [OKF](okf-open-knowledge-format.md) ·
[Adoption decision](../decisions/adopt-okf-icm-2026-09-10.md)