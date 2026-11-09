#!/usr/bin/env bash
set -euo pipefail

for port in 8080 8081 3000 9090; do
  fuser -k "${port}/tcp" 2>/dev/null || true
done
pkill -f 'kubectl port-forward' 2>/dev/null || true
sleep 1

GRAFANA_POD=$(kubectl get pod -n monitoring -l app.kubernetes.io/name=grafana -o jsonpath='{.items[0].metadata.name}')
PROM_POD=$(kubectl get pod -n monitoring -l app.kubernetes.io/name=prometheus -o jsonpath='{.items[0].metadata.name}')
echo "grafana_pod=${GRAFANA_POD}"
echo "prom_pod=${PROM_POD}"

setsid nohup kubectl port-forward --address 0.0.0.0 -n ingress-nginx svc/ingress-nginx-controller 8080:80 >/tmp/pf-app.log 2>&1 </dev/null &
setsid nohup kubectl port-forward --address 0.0.0.0 -n argocd svc/argocd-server 8081:80 >/tmp/pf-argo.log 2>&1 </dev/null &
setsid nohup kubectl port-forward --address 0.0.0.0 -n monitoring "pod/${GRAFANA_POD}" 3000:3000 >/tmp/pf-grafana.log 2>&1 </dev/null &
setsid nohup kubectl port-forward --address 0.0.0.0 -n monitoring "pod/${PROM_POD}" 9090:9090 >/tmp/pf-prom.log 2>&1 </dev/null &
disown || true
sleep 4

pgrep -af 'kubectl port-forward'
echo "=== pf logs ==="
cat /tmp/pf-app.log /tmp/pf-argo.log /tmp/pf-grafana.log /tmp/pf-prom.log
echo "=== health ==="
curl -s -o /dev/null -w "chat:%{http_code}\n" -H "Host: chat-app.com" --max-time 5 http://127.0.0.1:8080/ || true
curl -s -o /dev/null -w "argo:%{http_code}\n" --max-time 5 http://127.0.0.1:8081/ || true
curl -s -o /dev/null -w "grafana:%{http_code}\n" --max-time 8 http://127.0.0.1:3000/login || true
curl -s -o /dev/null -w "prom:%{http_code}\n" --max-time 5 http://127.0.0.1:9090/-/healthy || true
echo "WSL_IP=$(hostname -I | awk '{print $1}')"
