# Layer 0 — Workspace identity

You are in `~/agents`, the **M4 Mac mini orchestrator workspace** (user
`orchestrator`, git remote `ezybg7/m4-mini-orchestrator`, pushed nightly at
02:30 by `scripts/backup.sh`).

This workspace follows [SPEC.md](SPEC.md): an **ICM** staged workspace
(arXiv:2603.16021) whose knowledge layer is an **OKF** bundle
(Open Knowledge Format v0.1). Read SPEC.md before changing the structure.

## What is here

| Path | Layer | Holds |
|------|-------|-------|
| `CONTEXT.md` | 1 | The routing table. **Read it next.** |
| `references/` | 3 | Stable rules — machines, safety, conventions. The factory. |
| `memory/` | 3 | Durable knowledge as an OKF bundle. Enter at `memory/index.md`. |
| `pipelines/` | 2 | Numbered stage contracts for recurring workflows. |
| `runs/` | 4 | Per-run working artifacts. Disposable. The product. |
| `scripts/` | — | Mechanical work that needs no AI. Cron and launchd call these. |
| `queue/` | — | Task queue watched by launchd `com.user.claude-worker`. |
| `logs/`, `skills/`, `builds/` | — | Load-bearing or large; gitignored. |
| `_archive/` | — | Superseded files kept for history. Do not read for current state. |

## The five rules that govern work here

1. **One stage, one job.** A stage that rehearses does not also apply.
2. **Plain text is the interface.** Stages hand off through files on disk.
3. **Load only this stage's context.** Layers 0–2 always; Layer 3 and 4 only as
   the stage contract's `## Inputs` names them. Do not read the whole workspace.
4. **Every output is an edit surface.** Write to `output/`; a human may edit it
   before the next stage runs. Read whatever is there, not what you wrote.
5. **Configure the factory, not the product.** Rules go in `references/`;
   per-run material goes in `output/`. Never mix them.

## Two rules that decide where a fix goes

- **Edit the source, not the output.** If you correct the same thing on
  consecutive runs, the defect is in a stage contract or a reference file. Fix it
  there so every future run is correct. Patching the output patches one run.
- **Durable fact → `memory/`. This run's material → `runs/`.** If it will be true
  next week, it is a concept and needs frontmatter and an index entry. If it is
  scaffolding for today, it is an artifact and belongs in `runs/`.

## Where this does not apply

ICM covers workflows that are sequential, human-reviewed, and repeatable. It is
the wrong tool for real-time multi-agent collaboration, concurrent serving, and
automated mid-pipeline branching. Those belong in `scripts/` or in application
code — do not force them into a stage contract.

## Above this file

`~/.claude/CLAUDE.md` is the machine-wide preamble (shared-memory protocol,
spec-first rule, CodeGraph). It applies everywhere, not just here.
