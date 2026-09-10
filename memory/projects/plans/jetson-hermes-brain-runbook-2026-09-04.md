---
type: plan
title: Jetson Hermes brain runbook (2026-09-04)
description: 'Runbook for standing up the Jetson Orin Nano as Hermes''s local inference node: where it stands, what changed, and the steps to bring it up.'
tags: [pantry, skills, hermes, infra, database, acceptance, memory]
timestamp: 2026-09-04T00:00:00Z
permalink: agents/projects/plans/jetson-hermes-brain-runbook-2026-09-04
---

# Jetson Orin Nano 8 GB as Hermes's brain — runbook

_Written 2026-09-04 from Everett's ask ("set it up and permanently use it as the localized brain for Hermes; shift to Hermes as orchestrator; what tasks give a 24/7 development experience"). Builds on the 2026-08-19 plan (PR #101, closed because infra tooling lives in `~/agents`; preserved beside this note as `jetson-orin-node-spec-2026-08-19.md`) and on a web-research pass the same day. **✔** = verified against a primary source or on the mini · **?** = unverified, check on the device. Orchestrator tooling: this lives in `~/agents`, never in the pantry repo._

## 0. Where things stand (verified on the mini, 2026-09-04)

- **Hermes Agent v0.18.2** (git install, Python 3.11; latest is v0.21.0, 2026-08-31) runs the Discord gateway (launchd `com.user.hermes`, Discord connected, gateway RSS ≈ 49 MB). Brain: `gemini-flash-lite-latest` through Google's OpenAI-compatible endpoint (`model.provider: custom`, `context_length: 1000000`). Its `orchestrator` personality and SOUL.md make it a **relay**: delegate to Claude by writing `~/agents/queue/<slug>.task`, report results from `~/agents/logs/claude-*.json`, log; never implement; `delegate_task` forbidden (it would spawn a local model).
- **Hermes enforces `MINIMUM_CONTEXT_LENGTH = 64_000`** (`agent/model_metadata.py:194`, checked at agent init; `cli.py:6196` explains "tool schemas + system prompt use a large fixed prefix" and prints the Ollama fix `OLLAMA_CONTEXT_LENGTH=64000 ollama serve`). The July attempt died on exactly this: `Model qwen3-agent has a context window of 40,960 tokens, which is below the minimum 64,000` (the mini's `Modelfile.qwen3-agent` set `num_ctx 40960`).
- Hermes has: `fallback_providers` (with `key_env`), `ollama_num_ctx`, Tailscale `100.64/10` treated as a local endpoint with longer timeouts (`model_metadata.py:633`), an SSH terminal backend (`terminal.backend: ssh`, `TERMINAL_SSH_HOST/USER/KEY`), profile routing, `hermes cron` (create/edit/pause/run), a webhook platform (port 8644, HMAC), **A2A v1.0** (port 9900, ≥ v0.20), an ACP **server** adapter — and **no ACP client** for driving Claude Code (issue #5257 open).
- Hermes auto-injects Anthropic prompt caching for Claude models on native Anthropic / OpenRouter / `anthropic_messages` gateways (`_anthropic_prompt_cache_policy`, system + last 3 messages, TTL from `prompt_caching.cache_ttl`, currently `5m`). Its fixed prefix ≈ 22k tokens (skills snapshot 8.9k + ~35 tool schemas + system prompt).
- **Tailscale is live** on the mini (`m4-mini` 100.121.102.56, the MacBook Air, the iPhone); sshd listens; the mini **never sleeps** (`pmset sleep 0`, `womp 1`, `autorestart 1`). No Jetson is on the LAN or tailnet yet (ARP/mDNS/tailscale probed).
- Ollama on the mini still holds qwen3:8b, qwen3-agent(-128k), hermes-agent, llama3.1:8b, nomic-embed-text — idle (`ollama ps` empty). Lessons kept from July: llama3.1 **narrated** tool calls as text; qwen3's template emitted real `tool_calls`; a 7–8B model + 64K KV needs 10–13 GB — the RAM agent waves need.

## 1. What changed since the 08-19 plan

1. **The "8 GB cannot be the relay brain" verdict is obsolete.** It assumed dense 7–8B models (Llama-3.1-8B 128 KB of KV per token → 8.4 GB at 64K; Qwen3-8B 144 KB/token). Two 2026 hybrid models fit: **Qwen3.5-4B** (8 full-attention layers × 4 KV heads × 256 → **32 KB/token → 2.1 GB at 64K f16, 1.05 GB q8**) and **Nemotron 3 Nano 4B** (4 attention layers × 8 KV heads × 128 → **16 KB/token → 1.0 GB at 64K**, 262K max). A 64K tool-calling brain now fits in ~5–6 GB. ✔ (from the published `config.json` of each)
2. **JetPack 7.2.1 (Aug 2026)**: Ubuntu 24.04 + CUDA 13.2.1; NVIDIA **removed the SD-card image** — the dev kit installs from a **"Jetson ISO" USB stick with no Ubuntu host PC**, which removes the flash-from-a-Mac problem. Firmware must already be ≥ 36.x (Super kits shipped with JetPack 6.1+). ✔
3. **Price**: the Orin Nano Super Developer Kit went **$249 → $399 on 2026-07-22**; NVIDIA announced the **Jetson Orin Nano 2** (8 GB, 78 TOPS, 8-core CPU, "2× inference, 40 % less power") on 2026-08-25 for **H1 2027**, price undisclosed. ✔
4. **Ollama on JetPack 7.2**: GPU support landed around Ollama 0.32 (NVIDIA staff, 2026-07-15); some users had to delete a stale `/usr/local/lib/ollama/cuda_v12` and/or set `LD_LIBRARY_PATH=/usr/local/cuda-13.2/lib64` and `OLLAMA_IGPU_ENABLE=1`. Acceptance is `ollama ps` showing **100 % GPU**; otherwise llama.cpp. ✔
5. Gemini offload is no longer the motivation (Flash-Lite is cheap and paid); the motivation is a brain that is **ours, always on, free per token**, that never competes with agent waves for the mini's 16 GB, and survives mini reboots. The dollar case is weak (§7); the independence case is the real one.
6. Codex (spec 56) and the docs vault (spec 55) join the workflow — the local brain can read the generated board and post lane results.

## 2. Decide first (Everett)

| # | Decision | Default in this runbook |
|---|---|---|
| 1 | Buy the $399 Super kit now, or wait for Orin Nano 2 (H1 2027, ~2× speed, same 8 GB)? | buy now if the 24/7 front desk is wanted this quarter; the runbook is unchanged for the Nano 2 |
| 2 | Brain: Jetson (independence) vs Claude Haiku 4.5 via API with caching (quality per dollar, ~$10–60/mo) | Haiku now, Jetson promoted to the brain only after it clears §8; the Jetson hosts embeddings/summaries/health regardless |
| 3 | Primary model: Qwen3.5-4B (stronger benchmarks, thinking on by default — decide on/off for the relay) vs Nemotron 3 Nano 4B (smaller KV, NVIDIA-tuned, 18 tok/s measured) | Qwen3.5-4B, thinking off for the relay; Nemotron as the fallback pull |
| 4 | JetPack 7.2.1 (the only remaining install path; Ollama fix is two months old) vs hunting the archived 6.2.x SD image | 7.2.1 |
| 5 | Phase 2 topology: a second Hermes profile on the Jetson talking to the mini over A2A/webhooks, or one gateway on the mini for good | one gateway on the mini until a mini outage actually hurts |
| 6 | Nightly reflection: local model drafts, Claude finalises — or Claude only | local draft (saves one Claude session a night) once §8 passes |

## 3. Shopping list

- **Jetson Orin Nano Super Developer Kit** — $399 (19 V PSU, Wi-Fi/BT module and fan included; **no storage in the box**). ✔
- **NVMe 2280 PCIe 3.0 SSD, 500 GB–1 TB** (M.2 Key-M ×4; a second Key-M 2230 ×2 slot exists) — ~$50–80 ?. Never run the rootfs or models from a microSD.
- A **16 GB+ USB stick** for the Jetson ISO.
- A **DisplayPort monitor + USB keyboard** for the installer (the carrier has no HDMI), or a USB-TTL serial cable ? (NVIDIA's ISO flow assumes a console).
- Ethernet to the same LAN as the mini; a case is optional.

## 4. Setup runbook

1. **Firmware check (only if the kit is not a Super kit bought since 2025).** JetPack 7.2.1 needs JetPack-6-generation UEFI/QSPI firmware (≥ 36.x). Press Esc at the NVIDIA splash and read the version; if < 36.0 follow NVIDIA's JetPack 6.x firmware update path (JetPack 5.1.3 microSD → `sudo apt install nvidia-l4t-jetson-orin-nano-qspi-updater` → reboot). ✔ Super kits should already be ≥ 36.x ?.
2. **On the Mac:** download **Jetson ISO r39.2.1 (JetPack 7.2.1)** from NVIDIA's JetPack downloads page and write it to the USB stick with balenaEtcher. ✔
3. **Install the NVMe**, boot from the stick, press **Y within 30 s** at the firmware-update prompt, pick the NVMe as target, remove the stick, reboot, finish Ubuntu setup — user `orin`, hostname `jetson`, Ethernet. ✔ Fallback if 7.2.1 misbehaves: SDK Manager on an x86 Ubuntu host (a borrowed laptop, or a Ubuntu live USB on the Windows box; VMs need USB passthrough and are finicky). Flashing from macOS or Docker-on-Mac does not work. ✔
4. **Base OS and power mode:**

   ```bash
   sudo apt update && sudo apt full-upgrade -y
   sudo nvpmodel -q --verbose             # list modes; MAXN SUPER and 25W ids vary by release
   sudo nvpmodel -m <id of 25W or MAXN SUPER>   # persists across reboots ✔
   sudo systemctl set-default multi-user.target  # headless, saves RAM ?
   sudo pip3 install -U jetson-stats --break-system-packages && sudo reboot   # jtop ✔
   ```

   Use **25 W** for always-on: 35–47 % faster than 15 W, best tokens per joule, ≤ 73 °C; never 7 W for production (CMA fragmentation blocks model loads). ✔ `jetson_clocks` in a systemd unit is optional ? (pins clocks, raises idle power). `jtop` shows "JetPack NOT DETECTED" cosmetically on 7.2 ✔.
5. **Network and security** (the 08-19 decisions, unchanged):

   ```bash
   # static DHCP lease for the Jetson on the router ?
   sudo apt install -y ufw && sudo ufw default deny incoming && sudo ufw allow in on tailscale0 && sudo ufw enable
   # copy the mini's public key into ~/.ssh/authorized_keys, then in /etc/ssh/sshd_config:
   #   PasswordAuthentication no · PermitRootLogin no
   curl -fsSL https://tailscale.com/install.sh | sh
   sudo tailscale up --ssh --advertise-tags=tag:jetson
   ```

   Tailnet policy (admin console) ✔ syntax:

   ```jsonc
   { "tagOwners": { "tag:jetson": ["autogroup:admin"], "tag:mini": ["autogroup:admin"] },
     "acls": [ { "action": "accept", "src": ["tag:mini"], "dst": ["tag:jetson:11434", "tag:jetson:8080", "tag:jetson:22"] } ] }
   ```

   Tag the mini `tag:mini`, disable key expiry for the Jetson. `unattended-upgrades` with the default security-only origins should not touch NVIDIA's L4T repo ?.
6. **Inference server — Ollama (primary):**

   ```bash
   curl -fsSL https://ollama.com/install.sh | sh          # ships Jetson CUDA bundles ✔
   sudo systemctl edit ollama                              # add:
   #  [Service]
   #  Environment="OLLAMA_HOST=<jetson tailscale 100.x.y.z>:11434"
   #  Environment="OLLAMA_CONTEXT_LENGTH=65536" "OLLAMA_KEEP_ALIVE=-1"
   #  Environment="OLLAMA_MAX_LOADED_MODELS=1" "OLLAMA_NUM_PARALLEL=1"
   #  Environment="OLLAMA_FLASH_ATTENTION=1" "OLLAMA_KV_CACHE_TYPE=q8_0"
   sudo systemctl daemon-reload && sudo systemctl restart ollama
   ollama ps        # after a pull: must say 100% GPU ✔; if not, see §1.4 (stale cuda_v12 dir, LD_LIBRARY_PATH, OLLAMA_IGPU_ENABLE=1)
   ```

   `OLLAMA_NUM_PARALLEL=1` keeps one slot so the ~22k-token Hermes prefix stays cached between turns. Bind only to the Tailscale address — never `0.0.0.0`.

   **llama.cpp (fallback; always works, faster prefill):**

   ```bash
   git clone https://github.com/ggml-org/llama.cpp && cd llama.cpp
   cmake -B build -DGGML_CUDA=ON -DCMAKE_CUDA_ARCHITECTURES=87 && cmake --build build -j4   # ✔
   # systemd unit:
   ./build/bin/llama-server -m <model>.gguf -c 65536 -ngl 999 -fa on --cache-type-k q8_0 --cache-type-v q8_0 \
     --jinja --host 100.x.y.z --port 8080 --api-key <key> --metrics      # --jinja is required for tool calls ✔
   ```

   `jetson-containers` (dusty-nv) now supports JetPack 6.2 and 7 (`jetson-containers run $(autotag ollama)`) ✔ — valid, but the native service is simpler for 24/7.
7. **Models:**

   ```bash
   ollama pull qwen3.5:4b && ollama pull nemotron-3-nano:4b && ollama pull qwen3-embedding
   printf 'FROM qwen3.5:4b\nPARAMETER num_ctx 65536\n' > Modelfile && ollama create qwen35-hermes -f Modelfile   # ✔ the OpenAI endpoint cannot carry num_ctx
   ```

   | Candidate | Weights (Q4) | KV at 64K | Fits 8 GB | Tool calls | Decode tok/s on Orin Nano Super |
   |---|---|---|---|---|---|
   | **Qwen3.5-4B** (primary) | 3.4 GB | 2.1 GB f16 / 1.05 GB q8 | **yes, ~5.5–6 GB** | ✔ tools + thinking; BFCL-V4 50.3, TAU2 79.9, IFEval 89.8 | 20–30 ? (3–4B dense class: 28–43 ✔) |
   | **Nemotron 3 Nano 4B** (fallback) | 2.8 GB | 1.0 GB | **yes, ~4.5 GB**, 262K max | ✔ RL-trained tool use | **18** ✔ (NVIDIA, llama.cpp) |
   | Qwen3.5-9B | 5.3–6.6 GB | 2.1 / 1.05 GB | marginal (~7 GB) — not for 24/7 | ✔ | ~14–19 |
   | Gemma 4 E2B / E4B (QAT) | 4.3 / 6.1 GB | ? sliding-window | E2B at ≤ 32K ?; E4B no headroom | ✔ | E2B 25.7 ✔ at 4K |
   | Hermes 4 14B (Nous) | 9.0 GB | — | **no** (IQ3_M 6.9 GB leaves no KV room) | — | — |
   | Hermes 3 8B · Llama 3.x 8B · Qwen3 8B | 4.9–5.2 GB | 8–9 GB f16 | **no at 64K** | — | 14–15 ✔ |

   Nous ships no ≤ 8B Hermes 4, so the "Hermes brain" is Qwen or Nemotron. Embeddings: `qwen3-embedding` or `nomic-embed-text` via `/v1/embeddings` ✔ (Basic Memory keeps its own fastembed; Hermes's built-in memory uses none). STT: Hermes's local provider is `faster-whisper`; on aarch64 the CTranslate2 wheels are CPU-only — leave voice memos on the mini until phase 2 (whisper.cpp CUDA build on the Jetson is a known path).
8. **Smoke test from the mini** — the 08-19 "`tool_calls` gate":

   ```bash
   J=http://100.x.y.z:11434
   curl -s $J/v1/models
   curl -s $J/v1/chat/completions -H 'Content-Type: application/json' -d '{"model":"qwen35-hermes",
     "messages":[{"role":"user","content":"Queue a task called hello"}],
     "tools":[{"type":"function","function":{"name":"write_task","parameters":{"type":"object",
       "properties":{"slug":{"type":"string"},"body":{"type":"string"}},"required":["slug","body"]}}}]}'
   ```

   Pass: the reply carries a structured `tool_calls` array, not narrated JSON; `ollama ps` says 100 % GPU; `jtop` shows ~5–6 GB GPU RAM; the port is unreachable from the LAN and reachable over the tailnet.
9. **Hermes on the mini** (`~/.hermes/config.yaml`; then `launchctl kickstart -k gui/$(id -u)/com.user.hermes`):

   ```yaml
   model:
     default: qwen35-hermes
     provider: custom
     base_url: http://100.x.y.z:11434/v1        # http, /v1, tailnet address
     context_length: 65536
     ollama_num_ctx: 65536
   fallback_providers:
     - provider: custom                            # today's Gemini endpoint becomes the safety net ✔
       model: gemini-flash-lite-latest
       base_url: https://generativelanguage.googleapis.com/v1beta/openai/
       key_env: <the existing key's env var>
   ```

   `ollama_num_ctx` and the runtime context gate exist in the installed 0.18.2 ✔; Tailscale addresses get local-endpoint timeouts ✔. Run `hermes update` (0.18.2 → 0.21.0) before phase 2 — A2A needs ≥ 0.20. Then the **scripted verification rounds** from the 08-19 plan: from Discord, "status" (answered locally); "queue a task: add a one-line comment to X" (a `.task` file appears, the worker's ✅ post lands in `#reports`); a `RESUME:<session_id>` follow-up; a result relay with its `PR:` line. The July retirement was a **hallucinated action** at 40K context with a weaker model — three clean rounds before trusting it.
10. **Watch it.** Add to the mini's `watchdog.sh` (cron every 30 min): `curl -fsS -m 5 http://100.x.y.z:11434/v1/models >/dev/null || hermes send --to discord:#reports --quiet "⚠️ Jetson inference down; Hermes on the Gemini fallback"` ?. `jtop` for thermals; `unattended-upgrades`; `RuntimeWatchdogSec` in `/etc/systemd/system.conf` ?; the 08-19 failure-mode table (undervoltage shows as throttling, not an error).

## 5. Architecture

| Option | Where Hermes runs | Model | Bridge to the Claude queue | Verdict |
|---|---|---|---|---|
| **a** | mini (as now) | Jetson over Tailscale | none — same host writes `~/agents/queue` | **Phase 1** — six config lines; tokens never leave the mini; Gemini fallback automatic |
| b | Jetson | Jetson | Hermes SSH terminal backend → writes `.task` files on the mini; the worker still posts to Discord | front desk survives mini reboots — but the Jetson then holds a key that can write the queue: same blast radius plus a second host to secure |
| c | mini | Jetson | Hermes → Claude Code over ACP | **not paved** — Hermes is an ACP server only; #5257 open; the community `hermes-acp-bridge` must run where Claude is logged in (the mini) |
| **d** | Jetson (second profile) | Jetson | Hermes **webhook platform** (8644, HMAC) or **A2A** (9900, bearer, ≥ v0.20) exposed by the mini's Hermes, which writes the queue | **Phase 2** — standards-based, no shared FS, tokens stay on the mini; two gateways to operate |

**Phases.**

1. **Inference only (this month, after the hardware):** option a; Qwen3.5-4B at 64K; Gemini as fallback; measure real prefill/decode with `jtop`; the verification rounds in §4.9. Expected latency: warm Discord reply **5–15 s**, cold turn **30–70 s** (prefill ≈ 285–580 tok/s on this GPU against a ~22k-token prefix, cached afterwards), a 3–5-hop relay task **30–90 s** — versus seconds on Gemini or Haiku. That is acceptable for a queue front desk and unacceptable for chat-speed conversation; decision 2 in §2 hinges on it.
2. **Orchestrator duties on Hermes:** `hermes update`; `hermes cron` jobs (morning brief from the generated board + `gh pr list` run on the mini in no-agent script mode; nightly-reflection draft; health); memory curation; kanban. Optionally a second Hermes profile on the Jetson with the Discord gateway, dispatching to the mini over A2A/webhooks (option d) — the Jetson never holds the Claude OAuth token, `gh` or the repo.
3. **Hermes as the orchestrator brain:** the escalation rule below, Claude Code as the worker lane, later Codex through Hermes's opt-in Codex app-server runtime; NVIDIA's NemoClaw (alpha; sandboxes Hermes in OpenShell on JetPack 7.2) is worth watching, not adopting.

## 6. Task catalogue — what the local brain does, what stays with Claude

| Task | Local 4B on the Jetson | Claude via the queue |
|---|---|---|
| Discord/Telegram front desk: triage, "what's pending", status, answers from the memory vault | ✔ reliably (strict persona, few tools) | — |
| Write `.task` files with the right headers (`EFFORT:` / `MODEL:` / `RESUME:`) from a chat request | ✔ after the verification rounds | — |
| Nightly reflection **draft** (summarise the day's log, propose folds) | ✔ draft + diff proposal | skill edits and commits stay with Claude |
| Routing: thinking-heavy → `EFFORT:max`; implementation → `MODEL:opus` + `EFFORT:high` | ✔ | — |
| Memory curation (Basic Memory notes, dedupe, tags) | ✔ with review | — |
| Watchdogs: Jetson/mini health, Ollama/Hermes up, queue stuck, failed-task first-line triage (read the JSON, summarise, suggest a `RESUME`) | ✔ | the fix itself |
| CI/PR staleness, "blocked on Everett" from the generated board | `gh` needs a token → the poll runs on the mini (Hermes cron, script mode); the model only summarises | — |
| Reminders (Apple secret expiry 2027-02-18, Neon branch expiries), morning brief | ✔ (`hermes cron`) | — |
| Voice memos → task files | mini today (faster-whisper); Jetson in phase 2 | — |
| Embeddings / semantic search over the vault | ✔ (`qwen3-embedding`) | — |
| Specs, PRDs, code, reviews, debugging, design, migrations, merges | ✗ | ✔ always (Codex for reviews/tests, spec 56) |

**Escalation rule (the current `orchestrator` persona, restated):** answer locally only if the request is (1) read-only over local files or memory, (2) a routing or formatting job, or (3) trivially conversational. Anything that changes a repo, needs judgement about product or design, or has failed once locally → write a `.task` (thinking-heavy → `EFFORT:max`, else `MODEL:opus` + `EFFORT:high`), post "queued", stop.

## 7. Costs (2026-09-04 rates)

Per Hermes turn ≈ 22k-token fixed prefix + ~8k conversation (cache reads on Anthropic) + 1.5k fresh input + 400 output; one cache write per four turns. Volumes: light 30 turns/day, medium 150, heavy 500.

| Brain | Rate per MTok (in / out; cache read / write) | Per turn | Light | Medium | Heavy |
|---|---|---|---|---|---|
| Claude Haiku 4.5 (API, `provider: anthropic`) | $1 / $5; $0.10 / $1.25 | $0.013 | $12/mo | $60/mo | $200/mo |
| Claude Sonnet 5 (API) | $2 / $10; $0.20 / $2.50 | $0.027 | $24/mo | $122/mo | $405/mo |
| Claude Opus 5 (API) | $5 / $25; $0.50 / $6.25 | $0.067 | $60/mo | $300/mo | $1,000/mo |
| Gemini 2.5 Flash-Lite (paid; no caching assumed) | $0.10 / $0.40 | $0.003 | $3/mo | $15/mo | $50/mo |
| Gemini 3.5 Flash-Lite | $0.30 / $2.50 | $0.011 | $10/mo | $47/mo | $160/mo |
| **Jetson Orin Nano 8 GB, 4B model** | $0 per token; **≈ $470–520 once** (kit $399 + NVMe); idle 4.7 W, inference 8–12 W, 25 W peak → 4.4–8.8 kWh/mo ≈ **$1.3–2.6/mo** | $0 | ≈ $2/mo | ≈ $2/mo | ≈ $2/mo |
| VPS for the gateway only (Hetzner CX23 €5.49 / CAX11 €5.99) | hosts Hermes, cannot run a usable model | — | + €6/mo on top of an API brain |
| Rented 24 GB GPU (RTX 4090) for a 14B–32B model | $79/mo spot (interruptible) · $159–166/mo reserved · up to $446/mo | $0 | $160–270/mo | same | same |

Break-even of the Jetson: ≈ 4 months against Sonnet at medium volume, ≈ 8 months against Haiku, never against Gemini Flash-Lite. Claude Max does not cover API calls. A "VPC" in the AWS sense is a network, not compute; the comparable thing is a cloud VM, and the mini never sleeps, so a VPS buys nothing here. **The Jetson's case is independence — no caps, no per-token bill, works on the LAN, keeps the mini's RAM for agent waves, survives mini reboots — not savings.**

## 8. Acceptance criteria (phase 1)

- [ ] `ollama ps` shows the model at 100 % GPU; `jtop` ≈ 5–6 GB GPU RAM; the port answers only over Tailscale (`ufw` denies the LAN).
- [ ] The tool-call smoke test returns a structured `tool_calls` array on three of three runs.
- [ ] Hermes starts with the Jetson brain without the 64K error, and three scripted verification rounds pass from Discord (status · queue a task → worker ✅ · `RESUME:` follow-up).
- [ ] Measured: cold turn, warm turn and relay-task latencies recorded here; if the warm reply exceeds 15 s the front desk stays on Haiku/Gemini and the Jetson keeps the offload roles.
- [ ] The watchdog posts to `#reports` when the endpoint is down and Hermes falls back to Gemini on its own.
- [ ] Nothing on the Jetson can reach the mini's queue, `gh` or the Claude token (phase 1 has no Jetson → mini path at all).

## 9. Unverified — check on the device

Qwen3.5-4B tokens/s on Orin Nano (hybrid Gated-DeltaNet kernels may run slower than dense 4B); whether every Super kit bought in 2025–26 has ≥ 36.x firmware; whether the Jetson ISO installer runs fully headless over serial; Gemma 4 E2B KV size at 64K; the exact Ollama version that fixed JetPack 7.2 GPU support (0.32.0 reported working); `RuntimeWatchdogSec` and `unattended-upgrades` behaviour on 7.2.1; NVMe and case prices; Orin Nano 2 pricing; whether Hermes's `reasoning_effort: medium` maps onto Ollama's think toggle for Qwen3.5 (test with curl; a Modelfile or system prompt if not).

## 10. Sources

NVIDIA: [JetPack downloads](https://developer.nvidia.com/embedded/jetpack/downloads) · [Orin Nano dev kit quick start](https://docs.nvidia.com/jetson/orin-nano-devkit/user-guide/latest/quick_start.html) · [hardware layout](https://docs.nvidia.com/jetson/orin-nano-devkit/user-guide/latest/hardware_layout.html) · [firmware update](https://docs.nvidia.com/jetson/orin-nano-devkit/user-guide/latest/update_firmware.html) · [Super dev kit](https://www.nvidia.com/en-us/autonomous-machines/embedded-systems/jetson-orin/nano-super-developer-kit/) · [Orin Nano 2 announcement](https://nvidianews.nvidia.com/news/nvidia-announces-jetson-orin-nano-2-robotics-computer-to-redefine-entry-level-edge-ai) · [price increase (CNX)](https://www.cnx-software.com/2026/07/22/nvidia-increases-the-price-of-jetson-modules-and-devkits-by-up-to-101/) · [JetPack 7.2 practical guide (forum)](https://forums.developer.nvidia.com/t/setting-up-the-nvidia-jetson-orin-nano-super-dev-kit-on-jetpack-7-2-a-practical-guide-june-2026/372490) · [Ollama on JetPack 7.2 GPU fix (forum)](https://forums.developer.nvidia.com/t/jetpack-7-2-gpu-acceleration-issue/372521?page=2) · [idle power (forum)](https://forums.developer.nvidia.com/t/reducing-idle-power-on-orin-nano-super-dev-kit/358482) · [Jetson AI Lab Ollama](https://github.com/NVIDIA-AI-IOT/jetson-ai-lab/blob/main/src/content/tutorials/fundamentals/ollama.md) · [jetson-containers](https://github.com/dusty-nv/jetson-containers) · [NemoClaw](https://github.com/NVIDIA/NemoClaw).
Inference: [Ollama FAQ](https://docs.ollama.com/faq) · [Ollama OpenAI compatibility](https://docs.ollama.com/api/openai-compatibility) · [llama-server README](https://github.com/ggml-org/llama.cpp/blob/master/tools/server/README.md) · [Orin benchmarks (smolhub)](https://smolhub.com/posts/jetson-nano-super-benchmark-non-reasoning/) · [prefill/decode numbers (gist)](https://gist.github.com/yalexx/f9840e347c11f7d198ff7490570eb702) · [Qwen3.5-4B](https://huggingface.co/Qwen/Qwen3.5-4B) · [Nemotron 3 Nano 4B](https://huggingface.co/blog/nvidia/nemotron-3-nano-4b) · [Hermes 4 14B GGUF sizes](https://huggingface.co/bartowski/NousResearch_Hermes-4-14B-GGUF).
Hermes: [providers](https://hermes-agent.nousresearch.com/docs/integrations/providers) · [fallback providers](https://hermes-agent.nousresearch.com/docs/user-guide/features/fallback-providers) · [configuration](https://hermes-agent.nousresearch.com/docs/user-guide/configuration) · [A2A](https://hermes-agent.nousresearch.com/docs/user-guide/messaging/a2a) · [kanban worker lanes](https://hermes-agent.nousresearch.com/docs/user-guide/features/kanban-worker-lanes) · [Codex app-server runtime](https://hermes-agent.nousresearch.com/docs/user-guide/features/codex-app-server-runtime) · [platform support](https://hermes-agent.nousresearch.com/docs/getting-started/platform-support) · [v0.20.0](https://github.com/NousResearch/hermes-agent/releases/tag/v2026.8.3) · [v0.21.0](https://github.com/NousResearch/hermes-agent/releases/tag/v2026.8.31) · [ACP client issue #5257](https://github.com/NousResearch/hermes-agent/issues/5257).
Network and prices: [Tailscale Linux install](https://tailscale.com/kb/1031/install-linux) · [Tailscale ACLs](https://tailscale.com/kb/1018/acls) · [Anthropic pricing](https://www.anthropic.com/pricing) · [Gemini pricing (Morph)](https://www.morphllm.com/gemini-api-pricing) · [RTX 4090 cloud (getdeploying)](https://getdeploying.com/gpus/nvidia-rtx-4090) · [Hetzner (comparedge)](https://comparedge.com/tools/hetzner/pricing).