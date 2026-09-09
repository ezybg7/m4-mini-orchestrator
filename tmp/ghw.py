#!/usr/bin/env python3
import subprocess, sys
r = subprocess.run(["/opt/homebrew/bin/gh"] + sys.argv[1:], capture_output=True, text=True)
sys.stdout.write(r.stdout)
sys.stderr.write(r.stderr)
sys.exit(r.returncode)
