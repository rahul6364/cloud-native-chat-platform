#!/usr/bin/env bash
set -euo pipefail

# Recreate argocd-repo-server as headless so controller can reach pod IPs
# (ClusterIP routing is broken after WSL/Kind resume; pod-to-pod still works)
kubectl delete svc argocd-repo-server -n argocd
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: argocd-repo-server
  namespace: argocd
  labels:
    app.kubernetes.io/component: repo-server
    app.kubernetes.io/name: argocd-repo-server
    app.kubernetes.io/part-of: argocd
spec:
  clusterIP: None
  ports:
  - name: server
    port: 8081
    protocol: TCP
    targetPort: 8081
  - name: metrics
    port: 8084
    protocol: TCP
    targetPort: 8084
  selector:
    app.kubernetes.io/name: argocd-repo-server
EOF

sleep 5
kubectl get svc,endpoints argocd-repo-server -n argocd
kubectl delete pod argocd-application-controller-0 -n argocd --force --grace-period=0
sleep 20

# Resolve DNS from controller
kubectl exec -n argocd argocd-application-controller-0 -- \
  sh -c 'getent hosts argocd-repo-server.argocd.svc.cluster.local || nslookup argocd-repo-server; REPO=$(getent hosts argocd-repo-server | awk "{print \$1}" | head -1); echo REPO=$REPO; timeout 3 bash -c "</dev/tcp/$REPO/8081" && echo svc_ok || echo svc_fail'

kubectl annotate application chat-app -n argocd argocd.argoproj.io/refresh=hard --overwrite
kubectl annotate application monitoring-stack -n argocd argocd.argoproj.io/refresh=hard --overwrite
kubectl annotate application loki -n argocd argocd.argoproj.io/refresh=hard --overwrite
sleep 15
kubectl get applications -n argocd
echo "--- chat-app condition ---"
kubectl get application chat-app -n argocd -o jsonpath='sync={.status.sync.status} health={.status.health.status}{"\n"}{.status.conditions[*].message}{"\n"}'
