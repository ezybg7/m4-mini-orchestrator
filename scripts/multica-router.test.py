#!/usr/bin/env python3
"""Assertions for multica-router.py's outage mode. Run it before and after any change to it:

    python3 ~/agents/scripts/multica-router.test.py

It touches nothing real — the state file, the log and every CLI call are redirected into a
temporary directory, and any CLI call the harness has not been taught is an error, so a new
mutation cannot slip through unasserted. `--dry-run` on the live script is the other gate.
"""
import importlib.util, json, os, pathlib, sys, tempfile
from datetime import datetime, timedelta

spec = importlib.util.spec_from_file_location(
    "router", str(pathlib.Path(__file__).with_name("multica-router.py")))
R = importlib.util.module_from_spec(spec)
sys.argv = ["router"]                       # no flags: DRY, CODEX_BACK and CODEX_FORCE all False
spec.loader.exec_module(R)

tmp = tempfile.mkdtemp()
R.OUTAGE = os.path.join(tmp, "outage.json")
R.LOG = os.path.join(tmp, "router.log")
out = []
R.log = lambda m: out.append(m)
R.mc = lambda *a: (_ for _ in ()).throw(AssertionError("un-taught CLI call: %r" % (a,)))

failed = False
checks = 0


def say(t, ok):
    global failed, checks
    checks += 1
    print(("PASS  " if ok else "FAIL  ") + t)
    if not ok:
        failed = True


now = datetime.now().astimezone()
STAND_IN = R.STAND_IN_IMPLEMENTER
CODEX = "8b234c22-58d2-4e3e-9d89-73760b11347c"

# ---------------------------------------------------------------------- parse_retry_at
msg = ("You've hit your usage limit. Visit https://chatgpt.com/codex/settings/usage to "
       "purchase more credits or try again at Sep 19th, 2026 4:09 AM.")
got = R.parse_retry_at(msg)
say("parses the real message -> 2026-09-19T04:09:00-04:00",
    got and got.isoformat() == "2026-09-19T04:09:00-04:00")
say("parses a PM time", R.parse_retry_at("try again at Dec 1, 2026 11:30 PM").hour == 23)
say("parses noon as 12:00", R.parse_retry_at("try again at Jul 4th, 2027 12:00 PM").hour == 12)
say("parses midnight as 00:00", R.parse_retry_at("try again at Jul 4th, 2027 12:00 AM").hour == 0)
say("no match -> None", R.parse_retry_at("you are out of credits") is None)
say("bad month -> None", R.parse_retry_at("try again at Foo 9th, 2026 4:09 AM") is None)
say("bad day -> None", R.parse_retry_at("try again at Feb 31st, 2026 4:09 AM") is None)

# ----------------------------------------------------------- detection is not the capacity path
R._FAILED_COMMENTS = {"K1": (msg,), "K2": ("Selected model is at capacity",), "K3": ()}
say("usage limit detected", R.usage_limit_failure("K1"))
say("usage limit is NOT a capacity failure (Astra->Sol must not fire)", not R.capacity_failure("K1"))
say("capacity still detected", R.capacity_failure("K2") and not R.usage_limit_failure("K2"))
say("a clean issue triggers neither", not R.capacity_failure("K3") and not R.usage_limit_failure("K3"))

# ------------------------------------------------------------------- write / hold / expire
out.clear()
R.write_outage(now + timedelta(days=7), "test", "unit test")
say("write_outage writes the three keys",
    sorted(json.load(open(R.OUTAGE))) == ["reason", "set_by", "until"])
say("write_outage logs ON with the target",
    "codex outage mode ON until" in out[0] and "code -> claude-implementer" in out[0])
out.clear()
say("a future until holds the outage", R.codex_outage_tick([]) is not None and not out)

json.dump({"until": (now - timedelta(minutes=1)).isoformat(), "reason": "t", "set_by": "t"},
          open(R.OUTAGE, "w"))
out.clear()
say("a past until closes the outage", R.codex_outage_tick([]) is None)
say("...and deletes the file", not os.path.exists(R.OUTAGE))
say("...and logs the required wording",
    any("codex outage over — routing code back to codex-implementer" in l for l in out))
say("...and reminds about the squad by hand",
    any("restore codex-reviewer" in l and "by hand" in l for l in out))

# --------------------------------------------------------------------- unreadable / absent
open(R.OUTAGE, "w").write("{not json")
out.clear()
say("an unparseable file is treated as no outage and cleared",
    R.codex_outage_tick([]) is None and not os.path.exists(R.OUTAGE))
json.dump({"until": "whenever", "reason": "t", "set_by": "t"}, open(R.OUTAGE, "w"))
out.clear()
say("an unreadable until is reported and cleared",
    R.codex_outage_tick([]) is None and not os.path.exists(R.OUTAGE)
    and any("unreadable until" in l for l in out))
say("no file -> read_outage None", R.read_outage() is None)

# ------------------------------------------------------------------- open_outage_by_hand
out.clear()
say("bare flag is refused",
    R.open_outage_by_hand(None) is None and "needs an ISO-8601 timestamp" in out[-1])
out.clear()
say("a typo is refused, nothing written",
    R.open_outage_by_hand("2026-09-19 4pm") is None and not os.path.exists(R.OUTAGE)
    and "not an ISO-8601 timestamp" in out[-1])
out.clear()
say("a past timestamp is refused",
    R.open_outage_by_hand("2020-01-01T00:00:00-05:00") is None and "not in the future" in out[-1])
out.clear()
st = R.open_outage_by_hand("2026-09-19T04:15:00-04:00")
say("a good timestamp opens it with the offset kept",
    st and st["until"] == "2026-09-19T04:15:00-04:00" and st["set_by"] == "--codex-outage-until")
say("a naive timestamp is stamped with the local offset",
    R.open_outage_by_hand("2027-01-02T03:04:05")["until"].endswith(
        now.replace(year=2027, month=1, day=2, hour=3, minute=4, second=5,
                    microsecond=0).astimezone().strftime("%z")[:3] + ":00"))

# ------------------------------------------------------------------------------ clear_outage
out.clear()
R.clear_outage("--codex-back")
say("clear_outage removes the file and logs the wording + the reminder",
    not os.path.exists(R.OUTAGE)
    and "codex outage over — routing code back to codex-implementer" in out[-1]
    and "restore codex-reviewer" in out[-1] and "--codex-back" in out[-1])

# --------------------------------------------------------------- run_in_flight (the guard's eye)
RUNNING = [{"agent_id": STAND_IN, "status": "running", "completed_at": None}]
R.mc = lambda *a: json.dumps(RUNNING)
say("a running run of that agent is in flight", R.run_in_flight("AMBR-38", STAND_IN))
say("...but not for a different agent", not R.run_in_flight("AMBR-38", CODEX))
R.mc = lambda *a: "[]"
say("no active runs -> not in flight", not R.run_in_flight("AMBR-38", STAND_IN))
R.mc = lambda *a: json.dumps([{"agent_id": STAND_IN, "status": "completed"},
                              {"agent_id": STAND_IN, "status": "failed"}])
say("a finished run is not in flight (a --active-less CLI cannot fool it)",
    not R.run_in_flight("AMBR-38", STAND_IN))
for s in ("queued", "dispatched", "waiting_local_directory"):
    R.mc = lambda *a, s=s: json.dumps([{"agent_id": STAND_IN, "status": s}])
    say(f"{s} counts as in flight", R.run_in_flight("AMBR-38", STAND_IN))
R.mc = lambda *a: json.dumps({"runs": RUNNING})
say("a {runs: [...]} shape is accepted too", R.run_in_flight("AMBR-38", STAND_IN))
out.clear()
R.mc = lambda *a: None
say("an unreadable answer fails closed (in flight) and says so",
    R.run_in_flight("AMBR-38", STAND_IN) and "treating it as work in flight" in out[-1])
out.clear()
R.mc = lambda *a: "not json"
say("an unparseable answer fails closed (in flight) and says so",
    R.run_in_flight("AMBR-38", STAND_IN) and "treating it as work in flight" in out[-1])

# ----------------------------------------------------------------------------- hand_back_held
CARD = {"identifier": "AMBR-38", "status": "code", "assignee_id": STAND_IN, "assignee_type": "agent"}
R.mc = lambda *a: json.dumps(RUNNING)
out.clear()
say("a Code card mid-run with the stand-in holds the hand-back", R.hand_back_held([CARD]))
say("...and logs the required wording",
    out[-1] == "codex outage over but AMBR-38 has a claude-implementer run in flight — "
               "holding the hand-back")
say("a card in another column is not the guard's business",
    not R.hand_back_held([{**CARD, "status": "in_review"}]))
say("a Code card assigned to someone else is not the guard's business",
    not R.hand_back_held([{**CARD, "assignee_id": CODEX}]))
R.mc = lambda *a: "[]"
say("an idle stand-in does not hold the hand-back", not R.hand_back_held([CARD]))

# --------------------------------------------------- the expiry path holds, then hands back
def teach(runs, issues):
    """A CLI that answers only what this harness has taught it; records assigns, refuses the rest."""
    calls, assigns = [], []

    def mc(*a):
        calls.append(a)
        if a[:2] == ("issue", "list"):
            return json.dumps({"issues": issues, "has_more": False, "total": len(issues)})
        if a[:2] == ("agent", "list"):
            return json.dumps([{"id": STAND_IN, "name": "claude-implementer"},
                               {"id": CODEX, "name": "codex-implementer"}])
        if a[:2] == ("squad", "list"):
            return json.dumps([])
        if a[:2] == ("issue", "runs"):
            return json.dumps(runs.get(a[2], []))
        if a[:2] == ("issue", "timeline"):
            return ""
        if a[:3] == ("issue", "comment", "list"):
            return "[]"
        if a[:2] == ("issue", "assign"):
            assigns.append(a)
            return "ok"
        raise AssertionError("un-taught CLI call: %r" % (a,))
    return mc, calls, assigns


past = {"until": (now - timedelta(minutes=1)).isoformat(), "reason": "t", "set_by": "t"}
json.dump(past, open(R.OUTAGE, "w"))
R.mc, _, _ = teach({"AMBR-38": RUNNING}, [CARD])
out.clear()
held = R.codex_outage_tick([CARD])
say("expiry with a live stand-in run keeps the outage open", held is not None)
say("...keeps the state file", os.path.exists(R.OUTAGE))
say("...logs the hold, not the hand-back",
    any("holding the hand-back" in l for l in out)
    and not any("routing code back" in l for l in out))
R.mc, _, _ = teach({"AMBR-38": []}, [CARD])
out.clear()
say("expiry with an idle stand-in closes the outage", R.codex_outage_tick([CARD]) is None)
say("...deletes the state file", not os.path.exists(R.OUTAGE))
say("...and logs the hand-back", any("routing code back to codex-implementer" in l for l in out))

# ------------------------------------------------------- main(): --codex-back, held and forced
def run_main(codex_back, force, runs, issues, state=None):
    json.dump(state or past, open(R.OUTAGE, "w"))
    R.CODEX_BACK, R.CODEX_FORCE, R.CODEX_OUTAGE_UNTIL, R.DRY = codex_back, force, None, False
    R.mc, calls, assigns = teach(runs, issues)
    R._FAILED_COMMENTS = {}
    out.clear()
    rc = R.main()
    return rc, assigns, list(out)


rc, assigns, lines = run_main(True, False, {"AMBR-38": RUNNING}, [CARD])
say("--codex-back with a live run exits 0", rc == 0)
say("...keeps the state file", os.path.exists(R.OUTAGE))
say("...prints the hold message", any("holding the hand-back" in l for l in lines))
say("...points at --force", any("--force to clear it anyway" in l for l in lines))
say("...assigns nothing", not assigns)

rc, assigns, lines = run_main(True, True, {"AMBR-38": RUNNING}, [CARD])
say("--codex-back --force exits 0", rc == 0)
say("...deletes the state file regardless of the live run", not os.path.exists(R.OUTAGE))
say("...logs the hand-back naming --force",
    any("routing code back to codex-implementer (--codex-back --force)" in l for l in lines))
say("...and hands AMBR-38 back to codex-implementer",
    assigns and assigns[-1] == ("issue", "assign", "AMBR-38", "--to", "codex-implementer"))

rc, assigns, lines = run_main(True, False, {"AMBR-38": []}, [CARD])
say("--codex-back with an idle stand-in clears and hands back",
    rc == 0 and not os.path.exists(R.OUTAGE)
    and assigns[-1] == ("issue", "assign", "AMBR-38", "--to", "codex-implementer"))

rc, assigns, lines = run_main(True, False, {}, [], state=past)
os.remove(R.OUTAGE) if os.path.exists(R.OUTAGE) else None
R.CODEX_BACK, R.CODEX_FORCE = True, False
R.mc, _, _ = teach({}, [])
out.clear()
say("--codex-back with no file says so and exits 0",
    R.main() == 0 and any("nothing to clear" in l for l in out))

# ------------------------------------------------------------------ DRY guard on every mutation
R.DRY = True
R.CODEX_BACK = R.CODEX_FORCE = False
R.mc = lambda *a: json.dumps(RUNNING)
if os.path.exists(R.OUTAGE):
    os.remove(R.OUTAGE)
out.clear()
st = R.write_outage(now + timedelta(days=1), "dry", "dry")
say("DRY write_outage writes nothing but returns the state",
    st is not None and not os.path.exists(R.OUTAGE) and out[-1].startswith("WOULD open"))
json.dump({"until": (now + timedelta(days=1)).isoformat(), "reason": "t", "set_by": "t"},
          open(R.OUTAGE, "w"))
out.clear()
R.clear_outage("dry")
say("DRY clear_outage deletes nothing", os.path.exists(R.OUTAGE) and out[-1].startswith("WOULD clear"))
json.dump(past, open(R.OUTAGE, "w"))
R.mc, _, _ = teach({"AMBR-38": []}, [CARD])
out.clear()
say("DRY expiry keeps the file and says WOULD",
    R.codex_outage_tick([CARD]) is None and os.path.exists(R.OUTAGE)
    and any(l.startswith("WOULD clear") for l in out))

# ------------------------------------------------------------------------------ routing tables
say("outage routes only the code column",
    {**R.ROUTES, **R.OUTAGE_ROUTES} == {"todo": "claude-planner", "code": "claude-implementer",
                                        "in_review": "review"})
say("both implementers count as pipeline actors",
    {"codex-implementer", "claude-implementer"} <= R.PIPELINE_ACTORS)
say("the stand-in id matches the routed name", R.OUTAGE_ROUTES["code"] == "claude-implementer")
sys.argv.extend(["--codex-outage-until", "X"])
say("flag_value reads --flag value", R.flag_value("--codex-outage-until") == "X")
sys.argv[-2:] = ["--codex-outage-until=Y"]
say("flag_value reads --flag=value", R.flag_value("--codex-outage-until") == "Y")

print(f"\n{checks} assertions — " + ("SOME FAILED" if failed else "ALL PASSED"))
sys.exit(1 if failed else 0)
