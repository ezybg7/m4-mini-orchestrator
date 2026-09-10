#!/usr/bin/env python3
# Safe to delete. One-shot PR opener for feat/jetson-orin-setup-plan.
# gh is off the worker PATH; run it via a spawn with Homebrew on PATH
# (auth lives in the macOS keychain, so gh is already authenticated inside).
import os, subprocess, tempfile

REPO = "ezybg7/pantry"
BASE = "main"
HEAD = "feat/jetson-orin-setup-plan"
TITLE = "Spec: Jetson Orin Nano local AI worker/inference node for Hermes"

BODY = r"""## What

Adds `specs/jetson-orin-nano-setup.md` — a comprehensive architecture + setup
plan for standing up an **NVIDIA Jetson Orin Nano/NX** as an always-on local AI
node for the **Hermes orchestrator** on the m4-mini. Also adds one `—`-numbered
**infra** row to the specs index (same treatment as `nightly-sync.md`).

**Spec only — no code, no schema, no client/app surface, no hardware bought.**
This is an infra spec for the mini's `~/agents` orchestration stack, *not* an
Ambry (Neon/Cloudflare) feature. It lives in this repo because that's where this
project's infra/ops specs already live.

## Why

The Hermes gateway's conversational brain is Gemini `flash-lite`, whose free
tier is tightly capped (5 req/min · 20 req/day · 250k input-tok/min) on a key
**shared** with app-side AI — so offloadable work (embeddings, summarize,
title-gen, classify, reflection passes) burns quota we could run on hardware we
own. The old on-box local backend (Ollama `qwen3`) was retired and was CPU-bound
on the mini anyway. A cheap, low-power, always-on CUDA node on the tailnet gives
Hermes a **dedicated local inference endpoint** — and, optionally, a scoped
local-model worker lane.

## Design in one paragraph

Two independent surfaces, either shippable alone. **Role 1 (primary):** an
OpenAI-compatible inference server (Ollama via `jetson-containers`, TensorRT-LLM
as a later optimization) reachable **only over Tailscale** from the mini —
consumed first as auxiliary offload (Gemini-quota relief), later (NX 16 GB only)
as a Hermes fallback backend. **Role 2 (extension):** a `WORKER:jetson` queue
lane dispatched to a Jetson-local `systemd` watcher (analog of
`claude-worker.sh`) for latency-tolerant, non-frontier tasks. Security is parity
-or-better with the mini: **key-only SSH** (explicitly *not* repeating the mini's
open "SSH password auth ENABLED" audit finding), default-deny firewall, inference
bound to the tailnet interface only, Tailscale ACL as the auth boundary.

## Honest constraints the spec bakes in

- **8 GB Nano ≠ Hermes relay brain.** Hermes enforces a **≥64K context floor** at
  agent-init; an 8 GB board can't hold a 7–8B model *plus* a 64K KV cache. It
  stays an *auxiliary* endpoint (direct `/v1` calls bypass that gate). The
  relay-brain role is NX-16 GB-gated and trust-gated (scripted verification
  rounds), given the qwen hallucinated-action retirement history.
- **"16 GB" is an Orin NX, not a Nano** (Nano tops out at 8 GB) — this is the
  single biggest hardware decision.
- Reuses the qwen-era endpoint gotchas verbatim (`http://…/v1`, plaintext port)
  and the model-swap checklist (structured `tool_calls` are a hard gate for the
  worker role — the `llama3.1`-narrates trap).
- **Does NOT reopen** the closed (2026-07-20) local-VLM-for-receipts decision;
  only flags a possible re-eval as an open question.

## Decisions for you (Everett) — see the spec's §Open questions

1. **Nano 8 GB vs NX 16 GB?** 8 GB = aux + worker (cheaper, covers the core
   motivation). NX 16 GB additionally enables the relay-brain trial.
2. **Is Role 2 (local-model worker lane) wanted,** or is Role 1 (pure inference
   endpoint) the whole ask?
3. **Reopen the local-VLM-for-receipts decision?** Default: leave closed.
4. **Attempt the Hermes relay-brain migration at all,** given the qwen history?
   Default: aux-only, keep Gemini as the brain.
5. **Budget & siting** (PSU/NVMe/cooling; 24/7 power + airflow + network).

No sign-off needed to merge the *plan*; the questions above gate the *build*.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
"""

def main():
    env = {**os.environ, "PATH": "/opt/homebrew/bin:" + os.environ.get("PATH", "")}
    repo_dir = os.path.expanduser("~/code/pantry")
    with tempfile.NamedTemporaryFile("w", suffix=".md", delete=False) as f:
        f.write(BODY)
        body_path = f.name
    cmd = ["gh", "pr", "create", "-R", REPO, "--base", BASE, "--head", HEAD,
           "--title", TITLE, "--body-file", body_path]
    print("running:", " ".join(cmd[:8]), "--body-file", body_path)
    r = subprocess.run(cmd, cwd=repo_dir, env=env, capture_output=True, text=True)
    print("exit:", r.returncode)
    print("stdout:", r.stdout.strip())
    print("stderr:", r.stderr.strip())

if __name__ == "__main__":
    main()
