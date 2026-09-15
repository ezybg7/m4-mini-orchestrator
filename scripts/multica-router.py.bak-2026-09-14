#!/usr/bin/env python3
"""Assign the right actor for whatever column an issue sits in.

Multica triggers runs on ASSIGNMENT, never on status. Everett's board model is the other
way round: the column says what should happen to an issue. This closes that gap — it polls
the board and, when an issue's column implies an actor different from its current assignee,
it assigns that actor, which is what starts the run.

    Todo       -> claude-planner      PRD + spec (+ the HIG pass), opens the spec PR
    Code       -> codex-implementer   builds from the merged spec, opens the PR
    In Review  -> review (squad)      three lenses in parallel, one findings list

Backlog, Blocked, Done and Cancelled are never touched: they are parking, not stages.

The one rule that keeps this safe: **act only when the desired actor differs from the
current one.** A failed task leaves the assignee in place, so a failing agent is never
re-triggered in a loop — retries are deliberate (a human, or multica-restart-planner.sh).
An issue in In Review assigned to everettyan has been approved and is waiting on his merge;
it is left alone, or the router would drag it back to the reviewers forever.

Outage mode. A capacity failure is one model's problem, and the Astra->Sol fallback answers it.
When the Codex *account* runs out of credits, both its models fail identically and there is
nothing to fall back to — the work has to leave the runtime. While
~/agents/logs/.multica-codex-outage.json exists with an `until` in the future, Code routes to
claude-implementer instead, a card already handed to codex-implementer is re-routed once, and
the model fallback is skipped entirely. The file is written by --codex-outage-until, or by this
script the first time it sees the usage-limit message on a failed run, and dropped by
--codex-back or by `until` passing — but never while the stand-in still has a run in flight on
a Code card, because Multica starts a task on assignment and does not cancel the one already
running, so handing that card back would put two implementers on one branch. The review squad's
spec-conformance seat is a separate, manual swap: outage mode does not touch squads.
"""
import json, os, subprocess, sys

ENV = {**os.environ, "PATH": os.path.expanduser("~/.local/bin") + ":/opt/homebrew/bin:" + os.environ.get("PATH", "")}
# Absolute path, not a name: under launchd the parent PATH is bare, and subprocess resolves
# the executable from the PARENT environment even when env= carries a fuller PATH.
MULTICA = next((c for c in (os.path.expanduser("~/.local/bin/multica"), "/opt/homebrew/bin/multica",
                            "/usr/local/bin/multica") if os.path.exists(c)), "multica")
LOG = os.path.expanduser("~/agents/logs/multica-router.log")
LOCK = os.path.expanduser("~/agents/logs/.multica-router.lock")
RETRIED = os.path.expanduser("~/agents/logs/.multica-router-retried.json")
FALLBACK = os.path.expanduser("~/agents/logs/.multica-model-fallback.json")
OUTAGE = os.path.expanduser("~/agents/logs/.multica-codex-outage.json")

# The Codex agents and the model pair they run on. Everett wants Astra; Astra hits capacity
# ("Selected model is at capacity") and a capacity event is global to the model, not to one
# agent — so when any of them dies that way, all of them fall back, and an hour later they
# all go back to Astra to find out whether it has recovered.
# gpt agents that share the one Codex account, flipped Astra<->Sol together on a capacity failure.
# codex-reviewer was archived 2026-09-12 (no agent reviews its own provider's code; Claude reviews gpt code
# cross-provider). researcher-ambry moved to Claude 2026-09-12 (no gpt research). Only these two remain on gpt:
# the implementer and the spec-reviewer (the latter cross-reviews the Claude planner's specs).
CODEX_AGENTS = {"codex-implementer": "8b234c22-58d2-4e3e-9d89-73760b11347c",
                "codex-spec-reviewer": "f420ccd1-31fe-4c2b-9231-5b2a33de223e"}
PREFERRED, FALLBACK_MODEL, FALLBACK_MINUTES = "gpt-6-astra", "gpt-5.6-sol", 60
DRY = "--dry-run" in sys.argv
CODEX_BACK = "--codex-back" in sys.argv
CODEX_FORCE = "--force" in sys.argv


def flag_value(flag):
    """The value after a flag — `--flag value` or `--flag=value`. None when absent or bare."""
    for n, a in enumerate(sys.argv):
        if a == flag:
            return sys.argv[n + 1] if n + 1 < len(sys.argv) else None
        if a.startswith(flag + "="):
            return a.split("=", 1)[1]
    return None


CODEX_OUTAGE_UNTIL = flag_value("--codex-outage-until")

ROUTES = {"todo": "claude-planner", "code": "codex-implementer", "in_review": "review"}
# What Code routes to while the Codex account is out of credits: the Claude-runtime stand-in.
OUTAGE_ROUTES = {"code": "claude-implementer"}
# The reset Codex names is a week out on this plan; used when the message carries no time.
OUTAGE_DEFAULT_DAYS = 7
# The Claude-runtime stand-in the code column is routed to during an outage, by id: the daemon
# is asked, by agent id, whether one of its runs is still going before a card is handed back.
# (The review squad's spec-conformance stand-in is a manual squad swap and needs no id here.)
STAND_IN_IMPLEMENTER = "8342261f-9b94-428e-8b24-73533914993b"
# What `issue runs --active` counts as work in flight, restated so a CLI that ever answers with
# the full history instead cannot make a finished run read as one that is still going.
IN_FLIGHT = {"queued", "dispatched", "running", "waiting_local_directory"}
# Every actor this script may own. It is both sides of the outage swap, not just the routes in
# force right now, because a card left with the *other* implementer has to still read as a
# routed card — otherwise the "assigned to something else on purpose" guard below skips it and
# it never crosses over (in either direction: into outage mode, or back out of it).
PIPELINE_ACTORS = set(ROUTES.values()) | set(OUTAGE_ROUTES.values())
NEVER_TOUCH = {"backlog", "blocked", "done", "cancelled"}
# In Review assigned here means "approved, waiting on Everett" — not work for the reviewers.
PARKED_WITH = {"in_review": "everettyan"}


def mc(*args):
    r = subprocess.run([MULTICA, *args], env=ENV, capture_output=True, text=True)
    return r.stdout if r.returncode == 0 else None


def log(msg):
    from datetime import datetime
    line = f"{datetime.now():%F %T} {msg}"
    print(line)
    with open(LOG, "a") as f:
        f.write(line + "\n")



def already_retried(key, remember=False):
    """Rate-limit retries per issue, on disk, because the timeline is not a reliable memory.

    Reading "did this fail?" from the last few timeline entries looked sufficient and was
    not: re-assigning an issue appends events but does not remove the old task_failed, so
    the same issue qualified for a retry on three consecutive ticks and queued duplicate
    tasks behind the one already running. One retry per issue per hour, written down.
    """
    import time
    try:
        state = json.load(open(RETRIED))
    except Exception:
        state = {}
    now = time.time()
    state = {k: v for k, v in state.items() if now - v < 86400}
    recent = (now - state.get(key, 0)) < 3600
    if remember and not recent:
        state[key] = now
        try:
            with open(RETRIED, "w") as f:
                json.dump(state, f)
        except Exception as e:
            log(f"could not record the retry of {key}: {e}")
        return False
    return recent


def cancelled_by_server(key):
    """True when the issue's last run died to an infrastructure cancellation, not a decision.

    A daemon restart (bootout/bootstrap, a crash, a kickstart) cancels running tasks and
    stamps "task cancelled by server" on the issue. The task is gone, the assignee is
    unchanged, and nothing will ever pick the work up again — the one failure worth
    retrying automatically. Any other failure is left alone.
    """
    timeline = mc("issue", "timeline", key) or ""
    tail = [l for l in timeline.strip().split("\n") if l.strip()][-4:]
    if not any("task_failed" in l for l in tail):
        return False
    return any("cancelled by server" in l for l in tail)



def set_codex_models(model, why):
    for name, aid in CODEX_AGENTS.items():
        if mc("agent", "update", aid, "--model", model) is None:
            log(f"model switch FAILED for {name} -> {model}")
    log(f"codex agents -> {model} ({why})")


_FAILED_COMMENTS = {}


def failed_comments(key):
    """The newest comment texts on an issue whose last run failed; () when it did not fail.

    Two detectors now ask the same question of the same issues on the same tick — is this
    failure the model's capacity, or the account's credits? — and each answer costs two CLI
    calls. Read it once per run and let both read the cache.
    """
    if key in _FAILED_COMMENTS:
        return _FAILED_COMMENTS[key]
    texts = ()
    timeline = mc("issue", "timeline", key) or ""
    tail = [l for l in timeline.strip().split("\n") if l.strip()][-4:]
    if any("task_failed" in l for l in tail):
        out = mc("issue", "comment", "list", key, "--output", "json", "--compact") or "[]"
        try:
            cs = json.loads(out); cs = cs if isinstance(cs, list) else cs.get("comments", [])
            texts = tuple(c.get("content") or "" for c in cs)[-3:]
        except json.JSONDecodeError:
            texts = ()
    _FAILED_COMMENTS[key] = texts
    return texts


def capacity_failure(key):
    """True when the issue's newest comment is Codex's capacity error after a task_failed."""
    return any("at capacity" in t or "model_not_found_or_unavailable" in t
               for t in failed_comments(key))


def usage_limit_failure(key):
    """True when the newest comment after a task_failed is the account's usage-limit error.

    "You've hit your usage limit … try again at Sep 19th, 2026 4:09 AM" — the limit is on the
    ChatGPT account, so every Codex model under it fails the same way. Deliberately NOT one of
    capacity_failure's phrases: flipping Astra->Sol here would change models and change
    nothing, and would then hide the real cause behind an hour of pointless probing.
    """
    return any("hit your usage limit" in t for t in failed_comments(key))


def model_fallback_tick(issues):
    """Fall back on a capacity failure; restore the preferred model after FALLBACK_MINUTES."""
    import time
    try:
        state = json.load(open(FALLBACK))
    except Exception:
        state = {}
    now = time.time()
    if state.get("since"):
        if now - state["since"] > FALLBACK_MINUTES * 60:
            set_codex_models(PREFERRED, f"{FALLBACK_MINUTES} min elapsed — probing whether Astra has capacity again")
            state = {}
            json.dump(state, open(FALLBACK, "w"))
        return state
    for i in issues:
        if i.get("status") in NEVER_TOUCH:
            continue
        key = i.get("identifier")
        if capacity_failure(key):
            set_codex_models(FALLBACK_MODEL, f"capacity failure on {key}")
            state = {"since": now, "trigger": key}
            json.dump(state, open(FALLBACK, "w"))
            # a pipeline issue whose own run died needs a retry; a squad member's death is the lead's to re-dispatch
            if i.get("status") in ROUTES and i.get("assignee_type") == "agent" and not already_retried(key):
                already_retried(key, remember=True)
                mc("issue", "assign", key, "--unassign"); mc("issue", "assign", key, "--to", ROUTES[i["status"]])
                log(f"retried {key} after the model fallback")
            break
    return state


def read_outage():
    """The outage state, or None when there is no file or it does not hold a state.

    Anything that is not a non-empty JSON object is "no state", not "an odd state": the
    caller checks whether the file is nonetheless there and clears it, because a file that
    is present and ignored is worse than no file — it reads as outage mode to whoever looks.
    """
    try:
        state = json.load(open(OUTAGE))
    except Exception:
        return None
    return state if isinstance(state, dict) and state else None


def outage_deadline(state):
    """The state's `until` as an aware datetime, or None when it cannot be read."""
    from datetime import datetime
    try:
        until = datetime.fromisoformat(state["until"])
    except (KeyError, TypeError, ValueError):
        return None
    return until if until.tzinfo else until.astimezone()


def parse_retry_at(text):
    """The reset time Codex names in the usage-limit message, as an aware local datetime.

    "…try again at Sep 19th, 2026 4:09 AM" carries no zone, and the daemon relays it in the
    box's own time, so it is read as local and stamped with the offset in force on that date.
    """
    import re
    from datetime import datetime
    m = re.search(r"try again at\s+([A-Za-z]{3})[a-z]*\.?\s+(\d{1,2})(?:st|nd|rd|th)?,?\s+"
                  r"(\d{4})[, ]+(\d{1,2}):(\d{2})\s*([AaPp])\.?[Mm]", text)
    if not m:
        return None
    months = {name: n for n, name in enumerate(
        ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"], 1)}
    month = months.get(m.group(1).title())
    if not month:
        return None
    hour = int(m.group(4)) % 12 + (12 if m.group(6).upper() == "P" else 0)
    try:
        return datetime(int(m.group(3)), month, int(m.group(2)), hour, int(m.group(5))).astimezone()
    except ValueError:
        return None


def write_outage(until, reason, set_by):
    """Open outage mode. Returns the state so the caller's own tick already routes by it."""
    state = {"until": until.isoformat(), "reason": reason, "set_by": set_by}
    if DRY:
        log(f"WOULD open codex outage mode until {state['until']} ({reason})")
        return state
    try:
        with open(OUTAGE, "w") as f:
            json.dump(state, f, indent=2)
    except OSError as e:
        log(f"could not write the codex outage state file: {e}")
        return None
    log(f"codex outage mode ON until {state['until']} — code -> {OUTAGE_ROUTES['code']} "
        f"({reason}; set by {set_by})")
    return state


def clear_outage(why):
    """Drop the state file: from this tick on, Code routes to codex-implementer again."""
    if DRY:
        log(f"WOULD clear codex outage mode ({why})")
        return
    try:
        os.remove(OUTAGE)
    except OSError as e:
        log(f"could not delete the codex outage state file: {e}")
        return
    log(f"codex outage over — routing code back to {ROUTES['code']} ({why}); the review squad stays "
        f"all-Claude (codex-reviewer is retired; the spec-conformance seat is claude-spec-reviewer for good)")


def open_outage_by_hand(raw):
    """--codex-outage-until <ISO>: open outage mode until a timestamp a human passed.

    A bad timestamp is a typo, not a routing decision — say so and change nothing, rather
    than opening an outage that ends at an hour nobody meant.
    """
    from datetime import datetime
    if not raw:
        log("--codex-outage-until needs an ISO-8601 timestamp, e.g. 2026-09-19T04:15:00-04:00")
        return None
    try:
        until = datetime.fromisoformat(raw)
    except ValueError:
        log(f"--codex-outage-until: {raw!r} is not an ISO-8601 timestamp")
        return None
    if until.tzinfo is None:
        until = until.astimezone()
    if until <= datetime.now().astimezone():
        log(f"--codex-outage-until: {until.isoformat()} is not in the future — nothing opened")
        return None
    return write_outage(until, "codex account usage limit", "--codex-outage-until")


def run_in_flight(key, agent_id):
    """True when that agent has a run on this issue that has not finished.

    Unreadable counts as in flight. The two answers are not symmetric: holding a hand-back for
    one more tick costs a minute, and handing a card back under a live run costs a branch.
    """
    out = mc("issue", "runs", key, "--active", "--output", "json")
    if out is None:
        log(f"could not read the runs of {key} — treating it as work in flight")
        return True
    try:
        runs = json.loads(out)
        runs = runs if isinstance(runs, list) else runs.get("runs", [])
    except json.JSONDecodeError:
        log(f"the runs of {key} came back unparseable — treating it as work in flight")
        return True
    return any(r.get("agent_id") == agent_id and r.get("status") in IN_FLIGHT for r in runs)


def hand_back_held(issues):
    """True when a Code card is mid-run with the stand-in, so the hand-back has to wait.

    Multica starts a task on assignment and does not cancel the one already running, so handing
    a card back to codex-implementer while the stand-in is still building it puts two
    implementers on one branch — the AMBR-30 shape, with a push each. The outage stays open
    until the run ends; the other direction needs no guard, because a Codex run dies in seconds
    while the account is out of credits.
    """
    held = False
    for i in issues:
        if i.get("status") != "code" or i.get("assignee_id") != STAND_IN_IMPLEMENTER:
            continue
        key = i.get("identifier")
        if run_in_flight(key, STAND_IN_IMPLEMENTER):
            log(f"codex outage over but {key} has a claude-implementer run in flight — "
                f"holding the hand-back")
            held = True
    return held


def codex_outage_tick(issues):
    """Hold, close or open outage mode for this tick; returns the active state, or None.

    Opening it is automatic on purpose: the limit lands as a comment on whichever card was
    running, at whatever hour the credits ran out, and a pipeline that waits for a human to
    notice loses the night. The only thing it needs from the message is when to stop.
    """
    from datetime import datetime, timedelta
    state = read_outage()
    if state is None and os.path.exists(OUTAGE):
        log(f"codex outage state file does not hold a usable state ({OUTAGE})")
        clear_outage("unusable state file")
        return None
    if state:
        until = outage_deadline(state)
        if until is None:
            log(f"codex outage state file has an unreadable until ({state.get('until')!r})")
        elif until > datetime.now().astimezone():
            return state
        if hand_back_held(issues):
            return state
        clear_outage("the reset time has passed" if until else "unreadable until")
        return None
    for i in issues:
        if i.get("status") in NEVER_TOUCH:
            continue
        key = i.get("identifier")
        if not usage_limit_failure(key):
            continue
        message = next((t for t in failed_comments(key) if "hit your usage limit" in t), "")
        until = parse_retry_at(message)
        how = "reset time read from the message" if until else \
              f"no reset time in the message — default {OUTAGE_DEFAULT_DAYS} days"
        until = until or (datetime.now().astimezone() + timedelta(days=OUTAGE_DEFAULT_DAYS))
        return write_outage(until, f"codex usage limit hit on {key} ({how})",
                            "multica-router.py (auto-detected)")
    return None


def main():
    out = mc("issue", "list", "--output", "json")
    if not out:
        log("could not read the board"); return 1
    try:
        parsed = json.loads(out)
    except json.JSONDecodeError:
        log("board returned unparseable JSON"); return 1
    # `issue list` paginates: {has_more, issues, limit, offset, total}. `agent list` and
    # `squad list` return bare arrays. Accept either shape rather than assuming one.
    issues = parsed["issues"] if isinstance(parsed, dict) else parsed
    if isinstance(parsed, dict) and parsed.get("has_more"):
        log(f"note: board reports more issues than one page ({parsed.get('total')} total)")

    # Outage mode first: it decides where Code goes on this very tick, and whether the model
    # fallback runs at all. Both models are on the exhausted account, so probing Astra every
    # hour would buy nothing; when the outage clears, the next tick's fallback tick sees a
    # long-expired `since` and restores Astra by itself.
    if CODEX_BACK:
        state = read_outage()
        if not os.path.exists(OUTAGE):
            log("--codex-back: no codex outage state file — nothing to clear")
            outage = None
        elif state and not CODEX_FORCE and hand_back_held(issues):
            # Held, not failed: the file stays, this tick keeps routing Code to the stand-in
            # whose run it is, and the next --codex-back — or the next tick once `until` has
            # passed — hands the card back on its own.
            log("--codex-back: holding, the state file stays — re-run it when the run has "
                "finished, or pass --force to clear it anyway")
            outage = state
        else:
            clear_outage("--codex-back --force" if CODEX_FORCE else "--codex-back")
            outage = None
    elif CODEX_OUTAGE_UNTIL is not None:
        outage = open_outage_by_hand(CODEX_OUTAGE_UNTIL)
        if outage is None:
            return 1
    else:
        outage = codex_outage_tick(issues)
    routes = {**ROUTES, **OUTAGE_ROUTES} if outage else ROUTES

    if not DRY and not outage:
        model_fallback_tick(issues)

    names = {}
    for kind in ("agent", "squad"):
        listed = mc(kind, "list", "--output", "json")
        if listed:
            rows = json.loads(listed)
            for a in (rows if isinstance(rows, list) else rows.get(kind + "s", [])):
                names[a["id"]] = a["name"]

    for i in issues:
        status = i.get("status")
        if status in NEVER_TOUCH or status not in routes:
            continue
        key = i.get("identifier")
        current = names.get(i.get("assignee_id"), "")
        if i.get("assignee_type") == "member":
            current = "everettyan"          # the only member on this board
        if PARKED_WITH.get(status) == current:
            continue
        # Only the development pipeline is routed by column. An issue handed to some other
        # actor — the research squad, a one-off reviewer, a specialist — was assigned by a
        # human on purpose, and the column says nothing about it. Overriding that is how
        # AMBR-30 (a research question sitting in `todo`) got yanked from the research
        # squad to the planner mid-run, leaving its leader unable to be woken at all.
        # A human assignee is different: an issue parked with Everett and then moved
        # by him into a pipeline column is the normal way a blocked card re-enters
        # the loop, and it must route. Only another *agent or squad* is a deliberate
        # choice the router must not override.
        if current and current not in PIPELINE_ACTORS and current != "everettyan":
            continue
        want = routes[status]
        if current == want:
            # Normally a no-op, and deliberately so: a task that failed on its own terms
            # (an agent out of credits, a refusal) must not be re-triggered in a loop.
            # The exception is an infrastructure cancellation — a daemon restart kills
            # in-flight tasks with "task cancelled by server", which leaves the issue
            # stranded in the right column with the right assignee and nothing running.
            # That one is safe to retry, because nothing about the work was decided.
            if not cancelled_by_server(key) or already_retried(key):
                continue
            log(f"retrying {key} ({status}) — last run was cancelled by the server")
            if DRY:
                log(f"WOULD retry {key} by re-assigning {want}")
                continue
            already_retried(key, remember=True)
            # Re-assigning the same agent is a no-op, so the assignee has to be cleared
            # first for the assignment to register as a change and start a task.
            mc("issue", "assign", key, "--unassign")
        elif outage and status == "code" and current == ROUTES["code"]:
            # Outage mode inherits a card mid-flight: it sits in Code with the Codex
            # implementer's name on it and two runs that died on the usage limit. Hand it
            # across ONCE — its own key in the retry memory, so a failed hand-over is
            # retried next hour but a working one is never re-queued, and so this never
            # spends the card's ordinary retry budget.
            if already_retried(f"{key}:codex-outage"):
                continue
            log(f"codex outage — {key} ({status}) is with {current}, whose account is out of credits")
            if DRY:
                log(f"WOULD re-route {key} {current} -> {want}")
                continue
            already_retried(f"{key}:codex-outage", remember=True)
            mc("issue", "assign", key, "--unassign")
        if DRY:
            log(f"WOULD assign {key} ({status}) {current or '(none)'} -> {want}"); continue
        if mc("issue", "assign", key, "--to", want) is None:
            log(f"FAILED  {key} ({status}) -> {want}")
        else:
            log(f"assigned {key} ({status}) {current or '(none)'} -> {want}")
    return 0


if __name__ == "__main__":
    # One instance at a time. launchd fires every 60 s and a human may run it by hand;
    # two overlapping runs each enqueue a task for the same issue.
    import fcntl
    lock = open(LOCK, "w")
    try:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        print("another router run is in progress; exiting")
        sys.exit(0)
    sys.exit(main())
