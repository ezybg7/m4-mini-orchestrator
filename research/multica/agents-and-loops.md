---
type: research-brief
title: Multica — how it drives Claude Code and Codex, and how Everett's three loops map onto it
description: Design brief from reading multica v0.4.42 (commit 51803b3) at ~/agents/research/multica/src. Permission model is the first-class finding.
tags: [multica, codex, claude-code, security, loops]
timestamp: 2026-09-11T00:00:00Z
sources_root: ~/agents/research/multica/src
---

# Multica: agents, loops, and the permission model

## Verdict

**Not yet as-is; integrate with these guardrails.** Multica's daemon runs every assigned task as an unattended child of the daemon's OS user: Claude Code is launched with `--permission-mode bypassPermissions` and the daemon answers every permission prompt `allow`; Codex is launched as `codex app-server` with every approval request auto-accepted and, on macOS, a per-task `config.toml` that the daemon rewrites to `sandbox_mode = "danger-full-access"`. `HOME` is deliberately untouched so `gh`, `ssh`, `~/.claude`, `~/.codex/auth.json` and anything else the user can read are reachable, and the agent's default contract is to push a branch and open a PR with those credentials. Multica's own security page says it plainly: treat every run as unsandboxed and put the boundary outside the daemon. Run on the `orchestrator` account this reproduces the CI-triage RCE class we disabled on 2026-09-11 — with a wider trigger surface (any workspace member, comment, chat bot, webhook, or cron). The loops themselves map well onto issues, sub-issue stages, squads, skills and autopilots, but Multica has no debate/consensus primitive, no loop-until-satisfied, and no document store; each needs a bridge to our existing spec-first machinery. Precondition for any pilot: a dedicated Unix user for the daemon with its own Claude login, a deploy key, a scoped `gh` token, and no access to `~/agents`. Codex joins only after `probe.sh` passes against a Multica-prepared `CODEX_HOME`.

## 1. Runtime invocation

### Claude Code

Exact argv (`server/pkg/agent/claude.go:714-770`, `:41-90`):

```
claude -p --output-format stream-json --input-format stream-json --verbose \
  --permission-mode bypassPermissions --disallowedTools AskUserQuestion \
  [--strict-mcp-config] [--model M] [--effort E] [--max-turns N] [--resume SID] \
  <MULTICA_CLAUDE_ARGS…> <agent custom_args…> [--settings <envRoot>/…json] [--mcp-config <tmpfile>]
```

- Binary: `claude` on PATH or `MULTICA_CLAUDE_PATH` (`claude.go:42-47`; `CLI_AND_DAEMON.md:306`). A custom runtime profile may substitute a wrapper plus fixed args as a prefix (`launch.go:45-72`; `apps/docs/content/docs/daemon-runtimes.mdx:125-142`).
- Prompt: a stream-json user message written to stdin; stdin stays open for `control_request` frames (`claude.go:143-155`, `:785-803`).
- Permissions: `--permission-mode`, `-p`, `--output-format`, `--input-format`, `--mcp-config`, `--effort` are blocked from `custom_args` and profile prefixes (`claude.go:699-712`; `launch.go:477-503`). Every `control_request` (i.e. every permission prompt) is answered `behavior: allow` (`claude.go:449-491`). So Claude Code's own permission modes do **not** apply; only explicit deny rules (a `--settings` file or `--disallowedTools`) survive, and Multica uses `--settings` only for disabled-skill policy (`execenv/runtime_skill_policy.go:32-72`).
- Refuses to run bypass as root unless `IS_SANDBOX=1` (`claude.go:881-886`) — the only sandbox-related check.
- The user's own MCP servers are inherited unless the agent has a managed `mcp_config` (`claude.go:729-734`).

### Codex

Exact argv (`server/pkg/agent/codex.go:344-351`, `:1095-1129`):

```
codex [profile fixed_args] app-server --listen stdio:// <MULTICA_CODEX_ARGS…> <custom_args…> [--enable fast_mode]
```

Then JSON-RPC over stdio: `initialize` → `thread/start {model, cwd, approvalPolicy: null, sandbox: null, developerInstructions: null…}` → `turn/start {input: prompt}` (`codex.go:1978-2012`). Server requests `item/commandExecution/requestApproval`, `item/fileChange/requestApproval` are answered `accept`; `item/permissions/requestApproval` echoes back the requested network/filesystem grant for the turn (`codex.go:2793-2850`). Only `--listen` is blocked from custom args (`codex.go:32-34`).

Per-task `CODEX_HOME=<envRoot>/codex-home` (`daemon.go:8077-8081`), seeded from `~/.codex` (`execenv/codex_home.go:17-30`, `:198-319`): `auth.json` is **symlinked** (shared credentials), `config.toml` is copied and then rewritten:

- Managed block hoisted to the top: `sandbox_mode = "danger-full-access"` on darwin whenever the CLI version is below `CodexDarwinNetworkAccessFixedVersion`, which is the empty string, i.e. always (`execenv/codex_sandbox.go:34`, `:98-132`, `:352-363`). Any top-level `sandbox_mode`/`[sandbox_workspace_write]` in the user's copy is stripped first (`:403-429`). Linux and Windows default to the same (`:64-97`). A warn-level log records every unsandboxed run (`:440-478`).
- The user's `[shell_environment_policy]` is removed and replaced by `inherit = "all"`, `ignore_default_excludes = true`, `include_only = [<every daemon env name not containing KEY/SECRET/TOKEN, plus MULTICA_*>]` (`execenv/codex_shell_env.go:16-20`, `:42-110`, `:112-133`).
- `approval_policy` is not written; `thread/start` passes `nil`, so the copied value applies — moot, since the daemon accepts everything anyway.
- Codex-native multi-agent and auto-memory are disabled (`codex_home.go:302-316`).

### Working directory, CLAUDE.md / AGENTS.md

- Every task gets `MULTICA_WORKSPACES_ROOT/<workspace-slug>-<id>/<issue-key>-<id>/` with `workdir/`, `output/`, `logs/`, `multica-config/` (`execenv/execenv.go:373-382`, `:491-513`; root defaults to `~/multica_workspaces`, `CLI_AND_DAEMON.md:264`). `workdir/` starts **empty**; the agent runs `multica repo checkout <url>` which creates `workdir/<repo-name>/` as a git worktree off a bare cache in `.repos/`, on branch `agent/<agent>/<task-key>` (`execenv.go:409-412`; `cmd/multica/cmd_repo.go:51-53`, `:351-355`; `repocache/cache.go:838-843`).
- The daemon writes its **runtime brief** into `workdir/CLAUDE.md` (Claude) or `workdir/AGENTS.md` (Codex, others) inside HTML marker comments, appending to and never clobbering an existing file (`execenv/runtime_config.go:161-223`, `:225-275`). That brief is why `--append-system-prompt` / `developerInstructions` are not used (`claude.go:748-751`; `codex.go:1978-1983`).
- Consequence for us: in the `github_repo` flow the CLI's cwd is `workdir/`, one level **above** the checkout. Claude Code discovers `CLAUDE.md` and `.claude/settings.json` from cwd upward, so pantry's root `CLAUDE.md` is only pulled in lazily (when files under `workdir/pantry/` are read) and the repo's `.claude/settings.json` hooks — including `guard-bash.mjs` — are **not** loaded as project settings. Codex likewise reads `AGENTS.md` from cwd, and `.codex/rules/pantry.rules` loads only for the trusted path `/Users/orchestrator/code/pantry` (`~/agents/codex/config.toml:34-36`), which a Multica workdir is not. The `local_directory` resource in `worktree` mode puts cwd at the repo root instead, replaying uncommitted edits and leaving a branch `agent/<agent>/<issue>` in the user's repo (`project-resources.mdx:73-89`); `in_place` mode edits the user's checkout directly (`:58`, `:67-71`).

### Environment and credentials

Child env = daemon's `os.Environ()` minus `MULTICA_*` and five internal Claude markers (`claude.go:877-879`, `:919-967`), plus task values `MULTICA_TOKEN` (a task-scoped `mat_` token, 24 h, `daemon.go:153-162`, `auth-tokens.mdx:78-84`), `MULTICA_TASK_ID/AGENT_ID/WORKSPACE_ID/SERVER_URL/DAEMON_PORT`, `TMPDIR` (`daemon.go:164-180`), `PATH` prefixed with the multica binary dir (`:8069-8076`), `CODEX_HOME`, then the agent's `custom_env` (stored **plaintext** server-side, `agents-create.mdx:116-126`) with `HOME/PATH/USER/SHELL/TMPDIR/CODEX_HOME/MULTICA_*` blocklisted (`daemon.go:8113-8122`, `:9841-9849`). `HOME` and `XDG_*` are deliberately preserved so `gh`, `aws`, `kubectl`, npm work as in the user's shell (`daemon.go:8082-8089`; `security-model.mdx:45`). Git operations run with the full daemon env so credential helpers such as `gh` resolve (`repocache/cache.go:24-35`); the checkout's remote is rewritten to the real URL "so an agent's normal fetch / push commands still target GitHub" (`:953-959`).

### Do our controls survive? No.

| Control | Under Multica |
|---|---|
| `lane.sh` refuses `--yolo`/bypass, runs `codex exec` with `-c default_permissions=pantry-*` in a worktree under `~/codex-worktrees` (`lane.sh:35-39`, `:111-121`) | Not invoked. The daemon launches `codex app-server` directly with its own per-task config; the managed block sets `danger-full-access`. Whether Codex 0.153's `default_permissions` (copied from `~/.codex/config.toml:23`) still wins over the managed `sandbox_mode` is **unknown from this repo** — Multica's docs assert the run is unsandboxed (`security-model.mdx:44`). `probe.sh:2-12` is the only way to know. |
| Seatbelt denies `~/.claude/**`, `~/.ssh/**`, `~/.config/gh/**`, `~/agents/**`, `.env*` (`config.toml:55-65`) | Same uncertainty; and `shell_environment_policy inherit = "core"` (`config.toml:31-32`) is replaced by `inherit = "all"` + allowlist. `execpolicy` `git push` forbid does not load outside the trusted path. |
| `claude-worker.sh` exports the OAuth token and runs `claude -p` with default permissions (`claude-worker.sh:20-21`, `:65-68`) | Not invoked. Claude runs with bypass + auto-allow; it authenticates with whatever `~/.claude` holds for the daemon user and can `cat ~/.claude/oauth_token` and `~/agents/.env.acceptance` — exactly the finding of `~/agents/memory/daily-log/2026-09-11.md:14`. |

Multica's stance is explicit: the daemon user is the boundary; recommended setups are a dedicated Unix user, a container, or a VM (`security-model.mdx:10-32`). Custom runtime profiles allow a wrapper script as the command (`daemon-runtimes.mdx:125`), which is the hook for our bridges below.

## 2. Primitives

Data model (`server/pkg/db/generated/models.go`) and run loop:

- **Agent** (`:24-56`): name, `instructions`, `runtime_id` (a runtime = one machine + one CLI, `:82-100`, `daemon-runtimes.mdx:13`), `model`, `thinking_level`, `service_tier`, `custom_env`, `custom_args`, `mcp_config`, `permission_mode` (who may invoke it), `max_concurrent_tasks` (default 6). Instructions become the "Agent Identity" section of the brief and outrank the workflow, but only as prompt text (`runtime_config_sections.go:456-460`).
- **Skill** (`:1243-1263`): `SKILL.md` + files stored in Multica's DB, materialised per task into `.claude/skills/` or `$CODEX_HOME/skills/` (`providers.mdx:21-27`; `execenv.go:638`). Multica's `multica-platform` built-in skill is appended to every agent (`execenv.go:659-663`).
- **Issue** (`:764-793`): polymorphic assignee (member/agent/squad), `parent_issue_id`, `stage`, `metadata` (≤50 keys, `CLI_AND_DAEMON.md:679-702`), `properties`, `acceptance_criteria`. Seven status categories; `backlog` parks, leaving it starts a run (`issues.mdx:41-64`).
- **Task/Run** (`AgentTaskQueue`, `:109-179`): one CLI execution; `session_id`, `work_dir`, `branch_name`, `trigger_comment_id`, `chat_session_id`, `autopilot_run_id`, `is_leader_task`, `squad_id`, `originator_user_id`. Triggers: assignment, @-mention, chat, autopilot (`tasks.mdx:22-31`). Same-agent follow-ups coalesce (`mentioning-agents.mdx:48-52`).
- **Comment** (`:546-565`): threaded, resolvable; the only cross-agent channel. A plain reply routes to the thread's agent, else the assignee (`mentioning-agents.mdx:36-46`). Agents may @-mention agents; Multica dedupes but "does not decide when the collaboration should end" (`:71-73`).
- **Project** (`:1162-1188`): description enters every run's context; resources `github_repo` or `local_directory` land in `.multica/project/resources.json` (`projects.mdx:38-40`; `project-resources.mdx:17-23`).
- **Squad** (`:1271-1293`): one leader agent + members. Assigning to a squad wakes the leader only; it must delegate by pasting exact `mention://` links, record `multica squad activity`, stop, and is re-woken by member updates; it moves the parent to `in_review` only when the goal is met (`squads.mdx:29-64`). Squad instructions are leader-only (`:25`).
- **Autopilot** (`:205-222`, `:297-321`): runbook + assignee (agent or squad) + triggers (cron with IANA tz, webhook, manual); `create_issue` or `run_only` mode; auto-paused at 90 % failure over 50 runs (`autopilots.mdx:10-35`, `:41-55`, `:129-131`).
- **Chat** (`ChatSession`, `:506-524`): private, issue-less, one run per message (`chat.mdx:10-14`). **Channels** are Slack/Feishu/Telegram bots bound to one agent that feed chat sessions (`channels.mdx:41-49`) — not a workflow primitive.
- **Sub-issue stages**: `--stage N` groups children; when the lowest unfinished stage is all `done`/`cancelled` the parent's agent is woken once and decides whether to promote the next stage from `backlog` (`builtin_skills/multica-platform/references/issues.md:344-367`; `issues.mdx:97-103`). This is the only fan-out/fan-in barrier Multica has.

**"Hand back for review" mechanically:** the run posts its result as a comment (`runtime_config_sections.go:701-705`) and writes `in_review`; "`done` stays human" (`:709`) — a prompt contract, no server check found in `internal/handler`/`service`/`issuestatus`. The server itself flips status only on run failure (→`todo`) and on a merged PR carrying `Closes KEY` (→`done`) (`issues.mdx:59-64`; `github-integration.mdx:82-92`). **Merging and pushing:** Multica never merges (`project-resources.mdx:82`) and the GitHub App is read-only (`github-integration.mdx:10`), but the agent's default for code-changing work is to open or update a PR with the host's `gh` before its final comment (`references/issues.md:70-92`). Review gates are therefore: a human (or a designated agent) moving `in_review` → `done`, plus whatever branch protection GitHub enforces.

## 3. Loop mapping

Common skeleton: one **Project** per initiative (description = standing brief, resource = the repo the deliverable lands in), a **parent issue** per loop run, **staged sub-issues** as the pipeline, a **squad** whose leader promotes stages, and the deliverable as a **PR** into a git repo we treat as source of truth — never as issue text. Every agent runs on the dedicated-user runtime (see bridges).

### Research loop

| Piece | Design |
|---|---|
| Agents | `research-lead` (Claude, cheap model; squad leader; skill `loop-research-lead`: how to split a topic into 3–5 source angles and create staged sub-issues), `researcher-web` ×2 (Claude, skills `research-method`, `citation-format`; WebSearch/WebFetch), `researcher-repo` (Claude, reads source repos via `multica repo checkout`), `referee` (Claude Opus, skill `debate-referee`: build a claim × source disagreement table, ask each researcher one rebuttal via @-mention, then rule), `synthesist` (Claude Opus, skill `okf-concept-file`: frontmatter, links, `okf-check.py`). |
| Squad | `research-squad`, leader `research-lead`; squad instructions carry the stage template and a hard cap of two rebuttal rounds. |
| Structure | Project `Research`; parent issue "Research: <topic>"; stage 1 = one sub-issue per angle (todo), stage 2 = "Debate" (backlog, assignee `referee`), stage 3 = "Synthesis" (backlog, assignee `synthesist`). The stage barrier wakes the lead, which promotes. |
| Debate | Lives in the stage-2 sub-issue: the referee reads the stage-1 final comments, posts the disagreement table, @-mentions each researcher with its rebuttal question (one run each, coalesced), then posts the ruling and sets `in_review`. No Multica primitive does this; it is squad instructions + a skill + the round cap. |
| Source of truth | Not a Multica object. Bridge: the OKF vault (`~/agents/memory`, already a git repo) is the project's `github_repo` resource; the synthesist opens a PR adding `sources/<topic>.md` and linking `index.md`; CI runs `okf-check.py`; Everett or the orchestrator merges. Issues hold only links. |
| Autopilot | None by default; optional "refresh <topic>" cron in `create_issue` mode. |

### Development loop

| Piece | Design |
|---|---|
| Agents | `dev-lead` (Claude; leader), `prd-author` (Claude, model `fable`, skill `prd-template`), `prd-critic` (Claude Opus, skill `prd-review`), `spec-author` (Claude `fable`, skills `spec-template` = `specs/_TEMPLATE.md`, `pantry-data-modeling`), `spec-critic` (Claude Opus, skills `pantry-code-review`, `pantry-testing-strategy`), `codex-implementer`, `codex-spec-reviewer`, `codex-test-prover`, `codex-hunter` (all Codex, one agent per lane so each carries its lane skill and role), `pr-steward` (Claude; runs `npm run typecheck/lint/test`, pushes, opens the PR with `KEY:` in the title, never `Closes`). |
| Squad | `dev-squad`, leader `dev-lead`. Squad instructions encode the stage template and the review loop: "while the latest `spec-critic` verdict is `needs-attention`, create another `Spec review round N` sub-issue (max 4); on `approve`, promote." |
| Structure | Project = pantry (resource `github.com/…/pantry`, ref `main`). Parent issue per feature. Stages: 1 PRD (PR to `docs/prd/<feature>.md`) → 2 PRD debate: `prd-critic` and `prd-author` argue in one sub-issue, referee = `dev-lead`; any "we don't know X" spawns a **research-loop parent issue** assigned to `research-squad`, linked by `mention://issue` and blocked on → 3 PRD review (human `in_review`→`done`) → 4 spec (PR to `specs/<feature>.md`) → 5 spec reviews (loop above; each round a Codex `review` of the spec diff plus a Claude critique) → 6 implement (`codex-implementer`; task file = the merged spec's §Acceptance) → 7 spec-conformance review (`codex-spec-reviewer`, verdict JSON per `review-output.schema.json`) and test proof (`codex-test-prover`: every acceptance line has a named test) → 8 PR handoff (`pr-steward`, `in_review`) → human merge; `Closes KEY` only on the final PR. |
| Debate | Stage 2 and stage 5, same mechanic as research; the referee is the lead. |
| Spec-first bridge | Specs stay in `specs/`; the implementation sub-issue's description is the spec path plus commit SHA, never the body. `codex-implementer` refuses to start if the referenced spec is not on `main` (skill rule). Update-spec-in-same-PR stays a `pantry-code-review` check. |
| Codex lanes on cron | Autopilot `nightly-hunt` (`0 3 * * *` America/Los_Angeles, `create_issue`, assignee `codex-hunter`, project pantry) and `weekly-test-gaps` (`codex-test-prover`). Second-opinion review = @-mention `codex-spec-reviewer` on any PR-handoff issue. Rate-limit cooling (`lane.sh:41-46`) becomes the agent skipping with a `blocked` comment. |

### Marketing loop

| Piece | Design |
|---|---|
| Agents | `market-lead` (Claude; leader), `competitor-scout` ×2 (Claude, skill `competitor-profile`: features, pricing, reviews, cadence, weaknesses, with URLs), `positioning-analyst` (Claude Opus, skill `positioning-matrix`). |
| Squad | `marketing-squad`. |
| Structure | Project `Market`; parent "Sweep <month>"; stage 1 one sub-issue per competitor; stage 2 "Where we stand out / where they fall behind" matrix by the analyst; PR to the vault (`projects/ambry/market/<month>.md`). |
| Debate | Optional stage 2b: scouts challenge the matrix once. |
| Autopilot | Monthly `create_issue` cron assigned to the squad. |

### What Multica does not provide (all three loops)

- **No debate/consensus/vote primitive** — nothing in `server/` or the docs (grep). Bridged by a referee agent, squad instructions, and a round cap; cost is one run per rebuttal.
- **No loop-until-satisfied** — sub-issues are created by agents; the lead must re-create review rounds, and agent↔agent mentions have no built-in stop (`mentioning-agents.mdx:71-73`).
- **No document store** — durable context is the project description, skills, issue metadata (8 KB), attachments, comments. Our SoT stays in git (vault, `specs/`, `docs/prd/`) delivered as PRs.
- **Cross-agent context** is comments plus `.multica/project/resources.json`; workdirs are per task and reused only per issue+agent (`execenv.go:612-630`), so one agent's checkout is invisible to another — hand over via branch names in comments/metadata.
- **Nothing sandboxes the run** — the bridges: (a) dedicated `multica` Unix user (Multica's own recommendation) with its own Claude login, a pantry deploy key, a `gh` token limited to `contents:write`/`pull_requests:write` on pantry and the vault, no `~/agents`; (b) `MULTICA_DAEMON_MAX_CONCURRENT_TASKS=2` on the 16 GB mini; (c) Codex agents get `custom_args = ["-c","default_permissions=pantry-multica"]` — `-c` overrides beat the task-local `config.toml` from any argv position (`codex.go:1064-1067`) — where `pantry-multica` = `pantry-fix` plus loopback network so `multica issue …` reaches the self-hosted API; then a `probe.sh` variant run inside a real Multica task (`codex sandbox -P pantry-multica` against a `~/multica_workspaces` worktree) is the gate; (d) anything that must touch operator credentials (Neon owner string, prod deploys, `~/agents`) stays on `~/agents/queue` + `claude-worker.sh`, triggered by a Multica comment that the orchestrator reads, not by a Multica run.

## 4. Gaps and risks, ranked

1. **Operator-credential RCE by design.** Any trigger (assignment, comment, chat bot, webhook, cron, agent-to-agent mention) executes an auto-approved, unsandboxed CLI as the daemon user (`claude.go:720`, `:449-491`; `codex.go:2793-2802`; `codex_sandbox.go:98-132`; `security-model.mdx:12-22`). On `orchestrator` it exposes `~/.claude/oauth_token`, `~/.config/gh/hosts.yml`, `~/agents/.env.acceptance` — the 2026-09-11 finding, with a larger trigger surface. Blocker until the dedicated user exists.
2. **Codex containment likely defeated.** Managed block forces `danger-full-access` on darwin, strips `sandbox_mode`, replaces `shell_environment_policy`, and `execpolicy` rules do not load outside the trusted path. Precedence of `default_permissions` vs the managed `sandbox_mode` is unverified — and `probe.sh:4-9` already showed a silently ineffective profile once.
3. **`custom_env` and `mcp_config` are plaintext in the Multica DB** and travel to the runtime (`agents-create.mdx:121`; `how-multica-works.mdx:32-34`). Never put provider keys there; the isolated user's login is the credential.
4. **Repo guardrails not loaded in the `github_repo` flow**: cwd is the checkout's parent, so pantry's `.claude/settings.json` hooks (`guard-bash.mjs`, the `npm audit fix --force` block) and `.codex/rules` are bypassed. Mitigate with `local_directory` worktree mode from a clone owned by the daemon user, or with agent skills that `cd` and re-read `CLAUDE.md` first — verify per CLI.
5. **Default push-and-PR contract** (`references/issues.md:70-77`) means every code-changing run pushes with the daemon user's token; scope that token, protect `main`, and keep merge human (`done` is prompt-only).
6. **Prompt-only contracts**: Agent Identity boundaries, `done` stays human, no CI waiting (`runtime_config_sections.go:102`) — enforced by the model, not the server.
7. **Quota and memory**: default 20 tasks/daemon, 6/agent (`daemon-runtimes.mdx:72`); a runaway mention loop burns Claude/Codex quota fast and the mini has 16 GB.
8. **Self-hosting adds a privileged server** (90-day `mul_` PATs; webhook URLs are bearer credentials, `autopilots.mdx:87-91`) — see `hosting.md`.

## Open questions for Everett

1. Do you approve creating a dedicated `multica` Unix user on the mini (own Claude login, own Codex login, deploy key, scoped `gh` token, no `~/agents`)? Without it the verdict stays "not yet".
2. Where should loop outputs live as source of truth — the OKF vault repo as a `github_repo` project resource (agents open PRs into it, `okf-check.py` in CI), or Multica issues with a manual import step?
3. Codex inside Multica as a native runtime (after the probe passes with `-c default_permissions=pantry-multica`), or keep Codex behind `lane.sh` invoked from Claude runs for now?
4. May the referee trigger rebuttal rounds on its own (one paid run per researcher per round, capped at two), or should each round wait for your go?
5. Should Multica agents open PRs directly with the isolated user's token, or hand branches back for the queue worker to open PRs under your account?

## Sources

`server/pkg/agent/claude.go:41-47, 87-90, 122, 143-155, 449-491, 699-712, 714-770, 774-803, 877-886, 919-967` · `server/pkg/agent/codex.go:32-34, 344-351, 1043-1079, 1095-1129, 1978-2012, 2793-2850` · `server/pkg/agent/launch.go:45-72, 469-503` · `server/internal/daemon/daemon.go:153-180, 8032-8045, 8069-8089, 8113-8122, 8138, 9841-9849` · `server/internal/daemon/execenv/codex_sandbox.go:15-34, 64-132, 352-363, 403-429, 440-478` · `server/internal/daemon/execenv/codex_home.go:17-30, 194-319` · `server/internal/daemon/execenv/codex_shell_env.go:16-53, 106-133` · `server/internal/daemon/execenv/execenv.go:268-298, 373-382, 409-412, 491-513, 515-554, 605-663` · `server/internal/daemon/execenv/runtime_config.go:16-33, 161-223, 225-275` · `server/internal/daemon/execenv/runtime_config_sections.go:102, 456-460, 693-723` · `server/internal/daemon/execenv/runtime_skill_policy.go:32-72` · `server/internal/daemon/execenv/isolation.go:16-26` · `server/internal/daemon/repocache/cache.go:24-35, 838-843, 953-959` · `server/cmd/multica/cmd_repo.go:51-53, 340-366` · `server/pkg/db/generated/models.go:24-56, 82-107, 109-179, 205-222, 297-321, 506-524, 546-565, 764-793, 1162-1188, 1208-1221, 1243-1263, 1271-1293` · `server/internal/service/builtin_skills/multica-platform/SKILL.md:1-6, 59-67` · `…/references/issues.md:70-92, 228-262, 344-367` · `…/references/runtimes.md:68-106` · `CLI_AND_DAEMON.md:96, 148-151, 201-241, 264, 290, 306-320, 400, 679-702, 872-960` · `VISION.md:33-35, 58-70, 83-87` · `AGENTS.md:15-26` · `CLAUDE.md:16, 258-259` · `apps/docs/content/docs/security-model.mdx:10-48` · `daemon-runtimes.mdx:13, 72, 82-142` · `concepts.mdx:14-56` · `how-multica-works.mdx:32-38` · `agents.mdx:14-22, 36-45` · `agents-create.mdx:76-84, 100-136` · `assigning-issues.mdx:24-49` · `squads.mdx:8, 20-77` · `autopilots.mdx:10-55, 87-91, 127-131` · `issues.mdx:41-64, 97-103` · `projects.mdx:14-22, 38-53` · `project-resources.mdx:17-23, 58-97` · `tasks.mdx:22-52, 78-86` · `skills.mdx:8-10, 58-106` · `chat.mdx:10-14, 40-44` · `channels.mdx:26, 41-49` · `comments.mdx:22-37` · `mentioning-agents.mdx:36-52, 71-73` · `auth-tokens.mdx:34-43, 78-84` · `providers.mdx:21-27, 65-70, 81-91` · `github-integration.mdx:10, 82-92` · `developers/architecture.mdx:110-120` · local: `~/agents/codex/lane.sh:35-39, 41-46, 111-121, 158-164` · `~/agents/codex/probe.sh:2-12` · `~/agents/codex/config.toml:20-36, 41-65, 86-110` · `~/agents/scripts/claude-worker.sh:20-21, 65-68` · `~/agents/memory/daily-log/2026-09-11.md:8-14, 25`. No web sources were used.
