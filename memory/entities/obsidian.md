---
type: entity
title: Obsidian
description: Graph/editor view over the workspace. Installed, but pointed at ~/.hermes
  rather than here.
tags:
- memory
- tooling
timestamp: 2026-09-10 00:00:00+00:00
permalink: agents/entities/obsidian
---

# Obsidian

Installed on the mini. Its only vault today is `~/.hermes/.obsidian` — **it has
never been pointed at this workspace**, which is the gap.

## Why it fits with no adapter

An OKF bundle *is* the Obsidian shape: a folder of markdown, YAML frontmatter,
and links between files. Nothing has to be converted.

- OKF `tags:` are Obsidian's native tag field — the vault's tags become
  filterable the moment it opens.
- OKF `type:`, `description:`, `timestamp:` show up as Obsidian **properties**
  and are queryable there.
- Our links are relative markdown links, which Obsidian resolves, and its graph
  view renders them — so the 181 cross-links become the picture OKF describes:
  a graph richer than the folder tree.
- `index.md` files become the natural hub notes.

## How to open it

Open **`~/agents`** as the vault — not `~/agents/memory`. The whole workspace is
markdown, so `references/` and `pipelines/` come along, and links that cross from
a concept into a stage contract resolve.

`.obsidian/app.json` is committed and sets the settings that matter:
`useMarkdownLinks: true` and `newLinkFormat: "relative"`, so links Obsidian
creates match the ones the tools create. Without those two, Obsidian writes
`[[wikilinks]]` and the vault ends up with two link styles that only one reader
understands. Per-machine UI state (`workspace.json`) is gitignored.

## Contract

Obsidian is a **producer** — editing a note there is editing the bundle. After
bulk edits in Obsidian, run `okf-normalize.py` and `okf-check.py`, or let the
02:30 backup do it. See [Producers and consumers](../../references/tool-harmony.md).

Related: [OKF](../sources/okf-open-knowledge-format.md)