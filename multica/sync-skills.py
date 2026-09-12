#!/usr/bin/env python3
"""Deploy the skills our Multica agents need into the workspace, from their one home on disk.

The repo's .claude/skills/ is authoritative for pantry-*, ~/agents/skills for the personal
rulesets. This pushes them into the Multica workspace, which is the ONLY channel that reaches
a run: a task workdir is fresh, carries no repo checkout, and the daemon user has no
~/.claude/skills (probe AMBR-7). Re-run after editing a source SKILL.md — it updates in place
by name, so the workspace copy is a deployment, never a fork.
"""
import json, os, re, subprocess, sys

HOME = os.path.expanduser("~")
REPO = os.environ.get("REPO_SKILLS", f"{HOME}/code/pantry/.claude/skills")
USER = os.environ.get("USER_SKILLS", f"{HOME}/agents/skills")
ENV = {**os.environ, "PATH": f"{HOME}/.local/bin:/opt/homebrew/bin:" + os.environ.get("PATH", "")}

# (source dir, workspace skill name, optional filter for supporting files)
# The filter keeps a skill's *reference* material and leaves behind anything that only makes
# sense on the orchestrator account — apple-hig ships crawlers that fetch developer.apple.com,
# which no task should be running.
SOURCES = [
    (f"{REPO}/pantry-code-review", "pantry-code-review"),
    (f"{REPO}/pantry-security-basics", "pantry-security-basics"),
    (f"{REPO}/pantry-data-modeling", "pantry-data-modeling"),
    (f"{REPO}/pantry-testing-strategy", "pantry-testing-strategy"),
    (f"{REPO}/pantry-auth-setup", "pantry-auth-setup"),
    (f"{REPO}/pantry-before-launch", "pantry-before-launch"),
    (f"{USER}/typescript-style", "typescript-style"),
    (f"{USER}/apple-hig", "apple-hig", lambda rel: rel.startswith("references/")),
    (f"{USER}/code-graph-usage", "code-graph-usage"),
    (f"{USER}/neon-rehearsal", "neon-rehearsal"),
    (f"{USER}/research-method", "research-method"),
    (f"{USER}/debug-gate-failure", "debug-gate-failure"),
    # Neon's own platform skill (installed by `npx neon@latest skills`, untracked at
    # .agents/skills/). Its three references are vector/full-text/hybrid search, which
    # this product does not use — pooled-vs-direct, branching and migrations are the value.
    (f"{os.path.expanduser('~')}/code/pantry/.agents/skills/neon-postgres", "neon-postgres", lambda rel: False),
    # ---- vetted vendor skills (cloned under ~/agents/research/skills; refresh with git pull) ----
    # Expo: official, updated daily. Only the ones an implementer or reviewer of THIS app touches;
    # expo-design-system is deliberately omitted — Ambry has its own design-system spec and two
    # rulebooks for one surface is the conflict the instruction-following research warns about.
    (f"{HOME}/agents/research/skills/expo-skills/plugins/expo/skills/expo-overview", "expo-overview"),
    (f"{HOME}/agents/research/skills/expo-skills/plugins/expo/skills/expo-data-fetching", "expo-data-fetching"),
    (f"{HOME}/agents/research/skills/expo-skills/plugins/expo/skills/expo-native-ui", "expo-native-ui"),
    # Vercel: the React Native rule set (react-best-practices is Next.js-heavy; skipped).
    (f"{HOME}/agents/research/skills/agent-skills/skills/react-native-skills", "react-native-skills",
        lambda rel: rel.startswith("rules/")),
    (f"{HOME}/agents/research/skills/agent-skills/skills/writing-guidelines", "writing-guidelines"),
    # Cloudflare: official plugin skills already on the mini — the Worker and the per-household DO.
    (f"{HOME}/.claude/plugins/cache/cloudflare/cloudflare/1.0.0/skills/workers-best-practices", "workers-best-practices"),
    (f"{HOME}/.claude/plugins/cache/cloudflare/cloudflare/1.0.0/skills/durable-objects", "durable-objects"),
    # Anthropic: the API reference the Worker's model calls are written against.
    (f"{HOME}/agents/research/skills/anthropic-skills/skills/claude-api", "claude-api",
        lambda rel: rel.startswith("shared/") or rel.endswith(".md")),
]

def mc(*args, capture=True):
    r = subprocess.run(["multica", *args], env=ENV, capture_output=capture, text=True)
    if r.returncode != 0:
        raise SystemExit(f"multica {' '.join(args[:3])} failed: {(r.stderr or r.stdout).strip()[:400]}")
    return r.stdout

def description(path):
    """Read the frontmatter description, including YAML folded/literal block scalars.

    Neon's own skills write `description: >-` with the text on following indented lines;
    taking only the rest of the `description:` line yields the literal ">-" as the gallery
    subtitle. Anything after a block indicator is gathered until the indentation ends.
    """
    t = open(path).read()
    m = re.search(r"^---\n(.*?)\n---", t, re.S)
    if not m:
        return ""
    fm = m.group(1).split("\n")
    for i, line in enumerate(fm):
        if not line.startswith("description:"):
            continue
        head = line[len("description:"):].strip()
        if head.rstrip() in (">", ">-", ">+", "|", "|-", "|+"):
            body = []
            for nxt in fm[i + 1:]:
                if nxt.strip() and not nxt[:1].isspace():
                    break
                body.append(nxt.strip())
            head = " ".join(body)
        return " ".join(head.strip().strip("\"'").split())[:900]
    return ""

existing = {s["name"]: s["id"] for s in json.loads(mc("skill", "list", "--output", "json") or "[]")}

for entry in SOURCES:
    d, name = entry[0], entry[1]
    keep = entry[2] if len(entry) > 2 else (lambda rel: True)
    src = os.path.join(d, "SKILL.md")
    if not os.path.isfile(src):
        print(f"MISSING  {src}")
        continue
    desc = description(src)
    if name in existing:
        sid = existing[name]
        mc("skill", "update", sid, "--description", desc, "--content-file", src)
        print(f"updated  {name}  ({sid})")
    else:
        out = json.loads(mc("skill", "create", "--name", name, "--description", desc,
                            "--content-file", src, "--output", "json"))
        sid = (out.get("skill") or out)["id"]
        print(f"created  {name}  ({sid})")
    for root, _, files in os.walk(d):
        for f in sorted(files):
            if f == "SKILL.md" or f.startswith("."):
                continue
            full = os.path.join(root, f)
            rel = os.path.relpath(full, d)
            if not keep(rel):
                continue
            mc("skill", "files", "upsert", sid, "--path", rel, "--content-file", full)
            print(f"   file  {rel}")

print()
print(mc("skill", "list"))
