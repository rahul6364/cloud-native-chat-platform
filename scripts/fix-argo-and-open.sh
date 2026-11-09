#!/usr/bin/env bash
set -euo pipefail

# Recreate repo-server ClusterIP service to refresh kube-proxy rules
kubectl get svc argocd-repo-server -n argocd -o yaml \
  | sed '/resourceVersion:/d;/uid:/d;/clusterIP:/d;/clusterIPs:/,/ipFamilies:/d' \
  > /tmp/repo-svc.yaml || true

# Soft fix: delete endpoints refresh by restarting repo-server
kubectl rollout restart deployment argocd-repo-server -n argocd
kubectl rollout status deployment argocd-repo-server -n argocd --timeout=120s

# Wait and test ClusterIP
sleep 5
SVC_IP=$(kubectl get svc argocd-repo-server -n argocd -o jsonpath='{.spec.clusterIP}')
echo "repo-server ClusterIP=$SVC_IP"
kubectl exec -n argocd argocd-application-controller-0 -- \
  sh -c "timeout 3 bash -c '</dev/tcp/${SVC_IP}/8081' && echo svc_ok || echo svc_fail" || true

# Refresh apps
kubectl annotate application chat-app -n argocd argocd.argoproj.io/refresh=hard --overwrite
kubectl annotate application monitoring-stack -n argocd argocd.argoproj.io/refresh=hard --overwrite
kubectl annotate application loki -n argocd argocd.argoproj.io/refresh=hard --overwrite
sleep 10
kubectl get applications -n argocd

# Ensure port-forwards (kill by pid file pattern carefully)
for port in 8080 8081 3000 9090; do
  fuser -k ${port}/tcp 2>/dev/null || true
done
sleep 1

kubectl port-forward --address 0.0.0.0 -n ingress-nginx svc/ingress-nginx-controller 8080:80 >/tmp/pf-app.log 2>&1 &
kubectl port-forward --address 0.0.0.0 -n argocd svc/argocd-server 8081:80 >/tmp/pf-argo.log 2>&1 &
kubectl port-forward --address 0.0.0.0 -n monitoring svc/monitoring-stack-grafana 3000:80 >/tmp/pf-grafana.log 2>&1 &
kubectl port-forward --address 0.0.0.0 -n monitoring svc/monitoring-stack-kube-prom-prometheus 9090:9090 >/tmp/pf-prom.log 2>&1 &
sleep 4

echo "=== PF logs ==="
cat /tmp/pf-app.log /tmp/pf-argo.log /tmp/pf-grafana.log /tmp/pf-prom.log
echo "=== health ==="
curl -s -o /dev/null -w "chat:%{http_code}\n" -H "Host: chat-app.com" http://127.0.0.1:8080/ || true
curl -s -o /dev/null -w "argo:%{http_code}\n" http://127.0.0.1:8081/ || true
curl -s -o /dev/null -w "grafana:%{http_code}\n" http://127.0.0.1:3000/login || true
curl -s -o /dev/null -w "prom:%{http_code}\n" http://127.0.0.1:9090/-/healthy || true
