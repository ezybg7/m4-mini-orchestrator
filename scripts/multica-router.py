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
DRY = "--dry-run" in sys.argv

ROUTES = {"todo": "claude-planner", "code": "codex-implementer", "in_review": "review"}
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

    names = {}
    for kind in ("agent", "squad"):
        listed = mc(kind, "list", "--output", "json")
        if listed:
            rows = json.loads(listed)
            for a in (rows if isinstance(rows, list) else rows.get(kind + "s", [])):
                names[a["id"]] = a["name"]

    for i in issues:
        status = i.get("status")
        if status in NEVER_TOUCH or status not in ROUTES:
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
        if current and current not in ROUTES.values() and current != "everettyan":
            continue
        want = ROUTES[status]
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
