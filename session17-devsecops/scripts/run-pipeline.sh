#!/bin/bash
# Local, faithful execution of .github/workflows/devsecops.yml - same stages, same tools, same order:
# Build -> Unit Test -> SAST -> SCA -> Secret Scan -> Docker Build -> Image Scan -> Security Gate -> Push -> Deploy
#
# usage: scripts/run-pipeline.sh [SOURCE_DIR]
#   SOURCE_DIR defaults to the project root. Reports + per-stage logs go to SOURCE_DIR/reports/.
# env:   REGISTRY (default localhost:18420)   K8S_CONTEXT (default minikube)
set -uo pipefail
export PIP_DISABLE_PIP_VERSION_CHECK=1

PROJECT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$(cd "${1:-$PROJECT}" && pwd)"
REGISTRY="${REGISTRY:-localhost:18420}"
CTX="${K8S_CONTEXT:-minikube}"
NS=s17-devsecops
IMAGE_NAME=s17-devsecops
VENV=/tmp/s17-pipeline-venv          # application build/test environment
TOOLS=/tmp/s17-security-tools-venv   # isolated environment for the Python security scanners
R="$SRC/reports"
cd "$SRC"
rm -rf "$R" && mkdir -p "$R"

# image tag = short content hash of everything that goes into the image (like a git sha)
TAG=$(cat Dockerfile requirements.txt $(find app -type f -not -path '*/__pycache__/*' | sort) | shasum | cut -c1-7)
IMAGE="$IMAGE_NAME:$TAG"

N=0
stage() {  # stage "Name" function  -> runs function, tees output to reports/stage-NN-name.log
  N=$((N + 1))
  local name="$1" fn="$2" log
  log="$R/stage-$(printf %02d $N)-$(echo "$name" | tr 'A-Z ' 'a-z-').log"
  {
    echo "==================================================================="
    echo " STAGE $N: $name        (source: $(basename "$SRC"), image: $IMAGE)"
    echo "==================================================================="
  } | tee "$log"
  $fn 2>&1 | tee -a "$log"
  local rc=${PIPESTATUS[0]}
  if [ $rc -eq 0 ]; then echo "[STAGE $N: $name] SUCCESS" | tee -a "$log"
  else echo "[STAGE $N: $name] FAILED (exit $rc)" | tee -a "$log"; echo "PIPELINE STOPPED at stage $N ($name)"; exit $rc; fi
}

build() {
  rm -rf "$VENV" && python3 -m venv "$VENV" && "$VENV/bin/pip" install -q --upgrade pip
  "$VENV/bin/pip" install -q -r requirements.txt || return 1
  "$VENV/bin/python" -m compileall -q app && echo "compileall: all modules byte-compiled OK"
  "$VENV/bin/python" -c "from app.app import app; print('import check OK:', app.name, '- routes:', len(list(app.url_map.iter_rules())))"
}

unit_test() {
  "$VENV/bin/pip" install -q -r requirements-dev.txt || return 1
  "$VENV/bin/pytest" -v --cov=app --cov-report=term --junitxml="$R/junit.xml"
}

# Security scanners always write their JSON report and never stop the pipeline themselves:
# the Security Gate stage evaluates all reports together against security/gate-policy.json.
sast() {
  [ -x "$TOOLS/bin/bandit" ] || { python3 -m venv "$TOOLS" && "$TOOLS/bin/pip" install -q -r "$PROJECT/security/requirements-tools.txt"; }
  echo "--- bandit (Python SAST) ---"
  "$TOOLS/bin/bandit" -q -r app -c security/bandit.yaml -f json -o "$R/bandit.json"
  "$TOOLS/bin/bandit" -q -r app -c security/bandit.yaml -f custom \
    --msg-template "{severity:<6} {test_id} {relpath}:{line}  {msg}" | grep -v "^$" \
    | sed -E "s/(password: ')(.{4})[^']*'/\1\2****REDACTED'/" || true   # never print secret values in CI logs
  python3 -c "import json;d=json.load(open('$R/bandit.json'))['metrics']['_totals'];print('bandit totals: HIGH=%d MEDIUM=%d LOW=%d'%(d['SEVERITY.HIGH'],d['SEVERITY.MEDIUM'],d['SEVERITY.LOW']))"
  echo "--- semgrep (p/python community rules + security/semgrep.yml custom rules) ---"
  semgrep scan --metrics=off --quiet --config p/python --config security/semgrep.yml --json -o "$R/semgrep.json" app >/dev/null 2>&1
  python3 - "$R/semgrep.json" <<'EOF'
import json, sys
res = json.load(open(sys.argv[1]))["results"]
for r in res:
    print(f"{r['extra']['severity']:<8} {r['path']}:{r['start']['line']}  {r['check_id'].split('.')[-1]}")
print(f"semgrep findings: {len(res)} (ERROR={sum(r['extra']['severity']=='ERROR' for r in res)})")
EOF
  echo "--- hadolint (Dockerfile lint, informational) ---"
  hadolint --no-fail Dockerfile && echo "hadolint: done"
  return 0
}

sca() {
  echo "--- pip-audit (PyPI advisory DB / OSV) ---"
  "$TOOLS/bin/pip-audit" -r requirements.txt -f json -o "$R/pip-audit.json" --progress-spinner off 2>/dev/null
  "$TOOLS/bin/pip-audit" -r requirements.txt --progress-spinner off 2>&1 | head -25
  echo "--- trivy fs (dependency manifests, HIGH/CRITICAL, fixable) ---"
  trivy fs --quiet --config security/trivy.yaml --ignorefile security/.trivyignore -f json -o "$R/trivy-fs.json" .
  trivy fs --quiet --config security/trivy.yaml --ignorefile security/.trivyignore -f table . | head -40
  return 0
}

secret_scan() {
  echo "--- gitleaks (default rules + security/gitleaks.toml) ---"
  gitleaks dir . -c security/gitleaks.toml -f json -r "$R/gitleaks.json" --redact --no-banner 2>&1 | tail -3
  python3 -c "
import json;d=json.load(open('$R/gitleaks.json'))
[print(f\"LEAK  {x['RuleID']:<22} {x['File']}:{x['StartLine']}  secret={x['Secret']}\") for x in d]
print('gitleaks findings:', len(d))"
  return 0
}

docker_build() {
  docker build -t "$IMAGE" . 2>&1 | grep -E "^#[0-9]+ \[|naming to|DONE|ERROR|error" | tail -25
  [ "${PIPESTATUS[0]}" -eq 0 ] && docker images "$IMAGE_NAME" | head -5
}

image_scan() {
  echo "--- trivy image (OS packages + Python packages in the image) ---"
  trivy image --quiet --config security/trivy.yaml --ignorefile security/.trivyignore -f json -o "$R/trivy-image.json" "$IMAGE"
  trivy image --quiet --config security/trivy.yaml --ignorefile security/.trivyignore -f table "$IMAGE" | head -45
  return 0
}

security_gate() {
  python3 "$PROJECT/security/security_gate.py" "$R" "$PROJECT/security/gate-policy.json"
}

push_image() {
  docker tag "$IMAGE" "$REGISTRY/$IMAGE" && docker tag "$IMAGE" "$REGISTRY/$IMAGE_NAME:latest"
  docker push -q "$REGISTRY/$IMAGE" && docker push -q "$REGISTRY/$IMAGE_NAME:latest"
  echo "registry catalog: $(curl -s http://$REGISTRY/v2/_catalog)"
  echo "tags: $(curl -s http://$REGISTRY/v2/$IMAGE_NAME/tags/list)"
}

deploy() {
  minikube image load "$REGISTRY/$IMAGE" && echo "image loaded into cluster: $REGISTRY/$IMAGE"
  kubectl --context "$CTX" apply -f "$PROJECT/k8s/namespace.yaml"
  sed "s|__IMAGE__|$REGISTRY/$IMAGE|" "$PROJECT/k8s/deployment.yaml" | kubectl --context "$CTX" apply -f -
  kubectl --context "$CTX" apply -f "$PROJECT/k8s/service.yaml"
  kubectl --context "$CTX" -n $NS rollout status deploy/devsecops-app --timeout=180s || return 1
  kubectl --context "$CTX" -n $NS get deploy,pods,svc -o wide
  echo "--- smoke test (from inside the cluster) ---"
  kubectl --context "$CTX" -n $NS exec deploy/devsecops-app -- python -c \
    "import urllib.request as u;print(u.urlopen('http://devsecops-app/health').read().decode())"
}

stage "Build" build
stage "Unit Test" unit_test
stage "SAST" sast
stage "SCA" sca
stage "Secret Scan" secret_scan
stage "Docker Build" docker_build
stage "Container Image Scan" image_scan
stage "Security Gate" security_gate
stage "Push Image" push_image
stage "Deploy to Kubernetes" deploy
echo "PIPELINE SUCCEEDED - $REGISTRY/$IMAGE deployed to namespace $NS"
