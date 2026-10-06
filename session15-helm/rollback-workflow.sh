#!/bin/bash
# Session 15 - Task 2: complete Helm rollback workflow
# install -> upgrade -> verify -> upgrade again -> verify -> rollback -> verify
set -e
cd "$(dirname "$0")"
NS=s15-rollback; REL=webapp; PORT=18401
kubectl create ns $NS --dry-run=client -o yaml | kubectl apply -f - >/dev/null

verify() {  # $1 = label
  echo "===== verify: $1 ====="
  kubectl rollout status deploy/$REL-myapp -n $NS --timeout=180s
  sleep 3
  helm history $REL -n $NS
  kubectl get deploy,rs,pods -n $NS -o wide
  kubectl get deploy $REL-myapp -n $NS -o jsonpath='image={.spec.template.spec.containers[0].image} replicas={.status.readyReplicas}{"\n"}'
  kubectl port-forward -n $NS svc/$REL-myapp $PORT:80 >/dev/null 2>&1 &
  PF=$!; sleep 3
  curl -s http://localhost:$PORT/ | sed -n '2,3p' | sed 's/<[^>]*>//g'
  echo "open http://localhost:$PORT/ in the browser to check the page, then press Enter"; read -r
  kill $PF 2>/dev/null || true
}

echo "===== Step 1: helm install (revision 1) ====="
helm install $REL myapp -n $NS --wait --timeout 3m
verify "revision 1 (nginx 1.24, 1 replica)"

echo "===== Step 2: helm upgrade (revision 2) ====="
cat rollback-values/v2.yaml
helm upgrade $REL myapp -n $NS -f rollback-values/v2.yaml --wait --timeout 3m
verify "revision 2 (nginx 1.25, 2 replicas)"

echo "===== Step 3: helm upgrade again (revision 3) ====="
cat rollback-values/v3.yaml
helm upgrade $REL myapp -n $NS -f rollback-values/v3.yaml --wait --timeout 3m
verify "revision 3 (nginx 1.26, 3 replicas)"

echo "===== Step 4: helm rollback to revision 2 ====="
helm rollback $REL 2 -n $NS --wait
helm get values $REL -n $NS
verify "after rollback (revision 4 = copy of revision 2)"
