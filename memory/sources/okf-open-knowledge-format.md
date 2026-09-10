---
type: reference
title: Open Knowledge Format (OKF) v0.1
description: Google Cloud's open spec for representing knowledge as a directory of
  markdown files with YAML frontmatter. Governs this vault's format.
resource: https://cloud.google.com/blog/products/data-analytics/how-the-open-knowledge-format-can-improve-data-sharing
tags:
- protocol
- memory
- okf
timestamp: 2026-06-12 00:00:00+00:00
permalink: agents/sources/okf-open-knowledge-format
---

# Open Knowledge Format (OKF) v0.1

Sam McVeety and Amir Hormati, Google Cloud Data Analytics blog, 2026-06-12.
Read in full 2026-09-10. Adopted for this vault — see
[SPEC.md](../../SPEC.md) and [the adoption decision](../decisions/adopt-okf-icm-2026-09-10.md).

## The problem it names

Internal knowledge — a table's schema, a metric's business meaning, an incident
runbook, a join path, a deprecation notice — lives scattered across metadata
catalogs with their own APIs, wikis and shared drives, code comments, and the
heads of a few senior engineers. Every agent builder re-solves the same
context-assembly problem; every catalog vendor reinvents the same data model.

The answer is **a format, not another service**: something anyone can produce
without an SDK, consume without an integration, that survives moving between
systems and organizations, lives in version control beside the code it describes,
and is readable by humans and parseable by agents — the same file, no translation
layer.

## What a bundle is

A directory of markdown files. One file per concept; **the file path is the
concept's identity**. Each file has a small YAML frontmatter block for the fields
that need to be queryable — `type`, `title`, `description`, `resource`, `tags`,
`timestamp` — and a markdown body for everything else.

Concepts link to each other with **ordinary markdown links**, which turns the
directory into a graph of relationships richer than the parent/child links the
filesystem implies. Bundles may include `index.md` files for progressive
disclosure as agents navigate the hierarchy, and `log.md` files for chronological
history.

That is the whole format. No compression scheme, no runtime, no required SDK:
just markdown, just files, just YAML frontmatter.

## The three stated design principles

1. **Minimally opinionated.** OKF requires exactly one thing of every concept: a
   `type` field. What types exist, what other fields to include, what sections
   the body has — all left to the producer. *The spec defines the
   interoperability surface, not the content model.*
2. **Producer/consumer independence.** Who writes the knowledge is cleanly
   separated from who consumes it. A hand-authored bundle can be read by an
   agent; a pipeline-generated bundle can be browsed in a visualizer; a bundle
   written by one LLM can be queried by another. The format is the contract and
   the tooling at each end is independently swappable.
3. **Format, not platform.** Not tied to any cloud, database, model provider, or
   agent framework, and it will never require a proprietary account or SDK to
   read, write, or serve. The value of a knowledge format comes from how many
   parties speak it, not from who owns it.

## Prior art it formalizes

The pattern kept reappearing under different names — Obsidian vaults wired to
coding agents, the `AGENTS.md` / `CLAUDE.md` family of convention files, repos
full of `index.md` and `log.md` that agents consult before doing real work,
"metadata as code" repositories. Karpathy's LLM Wiki gist is the crispest
statement of why it works: *"LLMs don't get bored, don't forget to update a
cross-reference, and can touch 15 files in one pass."* The bookkeeping that makes
humans abandon personal wikis is exactly what LLMs are good at.

Each instance was bespoke, though. They all looked alike — markdown, frontmatter,
cross-links — but none were designed to cooperate, so the knowledge stayed siloed.

## How we apply it

Full mapping in [SPEC.md](../../SPEC.md) §2.1 as rules O1–O9, with the checker
`scripts/okf-check.py` enforcing what is mechanically checkable. Notably: `type`
is required and must be informative — the basic-memory default `type: note`
applied to everything, which types nothing.

Producer/consumer independence is live here, not theoretical: **basic-memory**
(MCP), **grep**, and **`okf-check.py`** all read this bundle independently, and
basic-memory writes to it too. That is why the frontmatter parser in
`scripts/okf_fm.py` merges stacked blocks — two producers, one file.

Related: [ICM paper](icm-folder-structure-as-agent-architecture.md) ·
[Adoption decision](../decisions/adopt-okf-icm-2026-09-10.md)