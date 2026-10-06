#!/usr/bin/env python3
"""Security gate: reads the JSON reports produced by every scanner and fails the
pipeline (exit 1) when any category exceeds the threshold in gate-policy.json.

usage: security_gate.py [REPORTS_DIR] [POLICY_FILE]
"""
import json
import os
import sys

reports = sys.argv[1] if len(sys.argv) > 1 else "reports"
policy_file = sys.argv[2] if len(sys.argv) > 2 else os.path.join(os.path.dirname(__file__), "gate-policy.json")
policy = json.load(open(policy_file))


def load(name):
    path = os.path.join(reports, name)
    if not os.path.exists(path):
        return None
    with open(path) as f:
        text = f.read().strip()
    return json.loads(text) if text else []


def trivy_count(data, severities):
    if data is None:
        return None
    return sum(1 for r in data.get("Results", []) for v in r.get("Vulnerabilities") or []
               if v["Severity"] in severities)


bandit = load("bandit.json")
semgrep = load("semgrep.json")
pip_audit = load("pip-audit.json")
trivy_fs = load("trivy-fs.json")
gitleaks = load("gitleaks.json")
trivy_img = load("trivy-image.json")

results = [
    ("SAST", "bandit HIGH severity", "sast_bandit_high",
     None if bandit is None else sum(1 for r in bandit["results"] if r["issue_severity"] == "HIGH")),
    ("SAST", "semgrep ERROR findings", "sast_semgrep_error",
     None if semgrep is None else sum(1 for r in semgrep["results"] if r["extra"]["severity"] == "ERROR")),
    ("SCA", "pip-audit vulnerable deps", "sca_pip_audit_vulns",
     None if pip_audit is None else sum(len(d.get("vulns", [])) for d in pip_audit["dependencies"])),
    ("SCA", "trivy fs HIGH/CRITICAL", "sca_trivy_fs_high_critical", trivy_count(trivy_fs, {"HIGH", "CRITICAL"})),
    ("SECRETS", "gitleaks leaked secrets", "secrets_gitleaks", None if gitleaks is None else len(gitleaks)),
    ("IMAGE", "trivy image CRITICAL", "image_trivy_critical", trivy_count(trivy_img, {"CRITICAL"})),
    ("IMAGE", "trivy image HIGH", "image_trivy_high", trivy_count(trivy_img, {"HIGH"})),
]

print("=" * 72)
print(f"{'STAGE':<9}{'CHECK':<30}{'FOUND':>7}{'MAX':>6}   RESULT")
print("-" * 72)
failed = 0
for stage, label, key, found in results:
    limit = policy[key]
    if found is None:
        status, failed = "FAIL (report missing)", failed + 1
        found = "-"
    elif found > limit:
        status, failed = "FAIL", failed + 1
    else:
        status = "PASS"
    print(f"{stage:<9}{label:<30}{found:>7}{limit:>6}   {status}")
print("-" * 72)
if failed:
    print(f"SECURITY GATE: FAILED ({failed} check(s) over threshold) - image will NOT be pushed or deployed")
    sys.exit(1)
print("SECURITY GATE: PASSED - image approved for push and deployment")
