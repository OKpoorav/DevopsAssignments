#!/bin/bash
# Session 15 - Task 3: Helm mini project (Notes app chart)
cd "$(dirname "$0")"
NS=s15-notes
kubectl create ns $NS --dry-run=client -o yaml | kubectl apply -f - >/dev/null

echo "===== chart structure, lint, template ====="
tree notes-chart
helm lint notes-chart
helm template notes-dev notes-chart | grep -E '^kind|replicas|image:|ENVIRONMENT|nodePort'

echo "===== install (development values) ====="
helm install notes-dev notes-chart -n $NS --wait --timeout 3m
kubectl get deploy,svc,cm,pods -n $NS
kubectl exec -n $NS deploy/notes-dev-deploy -- printenv APP_NAME ENVIRONMENT

echo "===== upgrade to production values ====="
helm upgrade notes-dev notes-chart -n $NS -f notes-chart/values-prod.yaml --wait --timeout 3m
kubectl get pods -n $NS -o 'custom-columns=NAME:.metadata.name,IMAGE:.spec.containers[0].image,STATUS:.status.phase'
kubectl exec -n $NS deploy/notes-dev-deploy -- printenv ENVIRONMENT
helm history notes-dev -n $NS

echo "===== simulate a bad upgrade ====="
helm upgrade notes-dev notes-chart -n $NS -f notes-chart/values-prod.yaml --set image.tag=broken-tag-does-not-exist --wait --timeout 60s
sleep 5
kubectl get pods -n $NS
helm history notes-dev -n $NS

echo "===== rollback to revision 2 and verify ====="
helm rollback notes-dev 2 -n $NS --wait --timeout 3m
helm history notes-dev -n $NS
kubectl rollout status deploy/notes-dev-deploy -n $NS --timeout=120s
sleep 20
kubectl get pods -n $NS -o 'custom-columns=NAME:.metadata.name,IMAGE:.spec.containers[0].image,STATUS:.status.phase'
minikube ssh "curl -s http://$(minikube ip):30415/ | grep -i title"

echo "===== package and clean up ====="
helm package notes-chart -d /tmp
helm uninstall notes-dev -n $NS --wait
helm list -n $NS
kubectl get all -n $NS
