#!/bin/bash
# Creates a copy of the project with a deliberately INSECURE change, to prove the security gate blocks it.
# The fake credentials are generated at runtime so no secret-looking string is ever committed to this repo.
# usage: demo/make-vulnerable.sh DEST_DIR
set -e
PROJECT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$1"; rm -rf "$DEST"; mkdir -p "$DEST"
rsync -a --exclude reports --exclude screenshots --exclude logs --exclude demo "$PROJECT/" "$DEST/"

rand() { LC_ALL=C tr -dc "$1" </dev/urandom | head -c "$2"; }
AWS_KEY="AKIA$(rand 'A-Z2-7' 16)"
AWS_SECRET="$(rand 'A-Za-z0-9' 40)"
GH_TOKEN="ghp_$(rand 'A-Za-z0-9' 36)"

# 1) insecure code (SAST) + hard-coded credentials (secret scan)
cat > "$DEST/app/insecure_utils.py" <<EOF
"""'Quick fix' helpers committed in a hurry - every line here is a security problem."""
import hashlib
import subprocess

AWS_ACCESS_KEY_ID = "$AWS_KEY"
AWS_SECRET_ACCESS_KEY = "$AWS_SECRET"
GITHUB_TOKEN = "$GH_TOKEN"


def export_report(filename):
    # command injection: user input concatenated into a shell command
    return subprocess.check_output("tar -czf /tmp/report.tgz " + filename, shell=True)


def quick_calc(expression):
    # arbitrary code execution
    return eval(expression)


def hash_password(password):
    # weak hash for passwords
    return hashlib.md5(password.encode()).hexdigest()


def run_debug(app):
    # Werkzeug debugger exposed on all interfaces
    app.run(host="0.0.0.0", port=5001, debug=True)
EOF

# 2) vulnerable, outdated dependency (SCA + image scan)
echo "requests==2.19.1   # pulls urllib3 1.23 / idna / chardet - known CVEs" >> "$DEST/requirements.txt"
echo "vulnerable copy created at $DEST"
