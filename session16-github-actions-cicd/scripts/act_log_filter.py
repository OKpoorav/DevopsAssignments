#!/usr/bin/env python3
"""Condense an `act` log for screenshots.
usage: act_log_filter.py LOG [job-substring] [--summary]
  --summary : only step results / job results
  default   : step results + the step's own output lines (pip/docker noise removed)
"""
import re
import sys

args = [a for a in sys.argv[1:] if not a.startswith("--")]
summary = "--summary" in sys.argv
log, job = args[0], (args[1] if len(args) > 1 else "")
NOISE = re.compile(r"WARNING: Running pip|Requirement already|Downloading|Collecting|Using cached|━|"
                   r"Installing collected|Attempting uninstall|Found existing|Uninstalling|notice\]|"
                   r"set-output|::add-matcher|::debug|#\d+ |sha256:|DONE \d|Download|Extract|Pull|"
                   r"Waiting|Verifying|Already exists|Successfully (un)?installed pip|DEP0|trace-deprecation")
EMOJI = {"⭐": "*", "✅": "[OK]", "🏁": "[JOB]", "❌": "[FAIL]", "🚀": ">>"}
for line in open(log, encoding="utf-8", errors="replace"):
    line = line.rstrip("\n")
    if job and job not in line:
        continue
    if any(x in line for x in ("🐳", "☁", "⚙", "🧪", "level=", "time=")):
        continue
    is_result = any(e in line for e in ("⭐", "✅", "🏁", "❌", "🚀"))
    if summary and not ("✅" in line or "🏁" in line or "❌" in line):
        continue
    if not is_result and (" | " not in line or NOISE.search(line) or not line.split(" | ", 1)[1].strip()):
        continue
    for k, v in EMOJI.items():
        line = line.replace(k, v)
    line = re.sub(r"\s{2,}\]", "]", line)
    print(line.encode("ascii", "replace").decode())
