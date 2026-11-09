#!/usr/bin/env bash
set -euo pipefail

REPO_IP=$(kubectl get pod -n argocd -l app.kubernetes.io/name=argocd-repo-server -o jsonpath='{.items[0].status.podIP}')
echo "REPO_IP=${REPO_IP}"
test -n "${REPO_IP}"

# Show current args
echo "Current args:"
kubectl get statefulset argocd-application-controller -n argocd -o jsonpath='{.spec.template.spec.containers[0].args}'
echo

# Replace args entirely with binary + --repo-server
kubectl patch statefulset argocd-application-controller -n argocd --type=json -p="[
  {\"op\":\"replace\",\"path\":\"/spec/template/spec/containers/0/args\",\"value\":[\"/usr/local/bin/argocd-application-controller\",\"--repo-server=${REPO_IP}:8081\"]}
]"

kubectl rollout status statefulset/argocd-application-controller -n argocd --timeout=120s
sleep 8

# Also patch argocd-server similarly so UI can generate diffs
kubectl patch deployment argocd-server -n argocd --type=json -p="[
  {\"op\":\"add\",\"path\":\"/spec/template/spec/containers/0/args/-\",\"value\":\"--repo-server=${REPO_IP}:8081\"}
]" 2>/dev/null || \
kubectl get deployment argocd-server -n argocd -o jsonpath='{.spec.template.spec.containers[0].args}' ; echo

kubectl annotate application chat-app -n argocd argocd.argoproj.io/refresh=hard --overwrite
sleep 20
kubectl get applications -n argocd
echo "---"
kubectl get application chat-app -n argocd -o jsonpath='sync={.status.sync.status} health={.status.health.status}'
echo
kubectl get application chat-app -n argocd -o jsonpath='{.status.conditions[0].message}'
echo
