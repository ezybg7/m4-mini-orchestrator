#!/bin/bash
# Schedules the nightly reflection. It does NOT define it.
#
# What the run does lives in the stage contracts under
# ~/agents/pipelines/nightly-reflection/ -- editable without touching this file,
# which is the point (ICM: the filesystem is the orchestration).
set -euo pipefail
d=$(date +%F)
P=~/agents/pipelines/nightly-reflection

cat > ~/agents/queue/reflect-$d.task <<TASK
Nightly reflection for $d.

Read $P/CONTEXT.md, then run its stages in order, each against its own contract:

  1. $P/01_survey/CONTEXT.md
  2. $P/02_skills/CONTEXT.md
  3. $P/03_memory_fold/CONTEXT.md
  4. $P/04_report/CONTEXT.md

Load only what each stage's \`## Inputs\` names -- not the whole workspace.
Write each stage's output where its \`## Outputs\` says, and satisfy its
\`## Verify\` before moving on. Use the date $d throughout.

Two gates that are not yours to cross: stage 2 pushes but never merges, and
stage 3 leaves the vault staged, never committed.

An idle night is a valid outcome. If stage 1 finds nothing, say so and make no
edits rather than manufacturing one.
TASK

~/agents/scripts/claude-worker.sh
