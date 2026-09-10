import os, glob
for p in glob.glob("/Users/orchestrator/agents/tmp_pr_*.py") + \
         glob.glob("/Users/orchestrator/agents/tmp_runs.py") + \
         glob.glob("/Users/orchestrator/agents/tmp_trigger_ci.py"):
    try:
        os.remove(p); print("rm", p)
    except Exception as e:
        print("skip", p, e)
