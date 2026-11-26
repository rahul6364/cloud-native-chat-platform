# Deployment layout

| Path | Purpose |
|------|---------|
| `deploy/argocd/chat-app.yaml` | ArgoCD app — Helm chart at `helm/chat-app` |
| `deploy/argocd/monitoring.yaml` | Prometheus + Grafana (`kube-prometheus-stack`) |
| `deploy/argocd/loki.yaml` | Loki single binary (log storage, `loki` chart 7.x) |
| `deploy/argocd/alloy.yaml` | Grafana Alloy DaemonSet (collects pod logs → Loki) |
| `deploy/kind/kind-config.yaml` | Kind cluster with host ports 80/443 |
| `deploy/secrets/` | Kubeseal cert + re-sealing instructions (cert is gitignored) |

## Apply GitOps apps

```bash
kubectl apply -f deploy/argocd/chat-app.yaml
kubectl apply -f deploy/argocd/monitoring.yaml
kubectl apply -f deploy/argocd/loki.yaml
kubectl apply -f deploy/argocd/alloy.yaml
```

## Monitoring (port-forward)

```bash
kubectl get pods -n monitoring
kubectl port-forward -n monitoring svc/monitoring-stack-grafana 3000:80
kubectl port-forward -n monitoring svc/monitoring-stack-kube-prom-prometheus 9090:9090
```

- Grafana: http://localhost:3000 — **Explore → Loki** for logs, **Explore → Prometheus** for metrics.
  Credentials come from secret `grafana-admin-credentials` (sealed in `deploy/secrets/`), not fixed defaults:
  ```bash
  kubectl -n monitoring get secret grafana-admin-credentials \
    -o jsonpath='{.data.admin-user}'     | base64 -d; echo
  kubectl -n monitoring get secret grafana-admin-credentials \
    -o jsonpath='{.data.admin-password}' | base64 -d; echo
  ```
- Prometheus: http://localhost:9090

## Application metrics (backend)

The API exposes Prometheus metrics at `GET /metrics`:

- `chatapp_http_requests_total` — request count by method, route, status
- `chatapp_http_request_duration_seconds` — latency histogram
- `chatapp_socket_connections_active` — Socket.io connections
- `chatapp_active_users` — online users (socket map)

Scraped via `ServiceMonitor` when `metrics.serviceMonitor.enabled` is true in `helm/chat-app/values.yaml`.

Example PromQL in Grafana:

```promql
rate(chatapp_http_requests_total[5m])
histogram_quantile(0.95, sum(rate(chatapp_http_request_duration_seconds_bucket[5m])) by (le))
chatapp_active_users
```

Example LogQL in Grafana (Loki — labels: `namespace`, `pod`, `container`, `app`, `node`, `stream`):

```logql
{namespace="chat-app", app="backend"}
{namespace="chat-app", app="backend", stream="stderr"}   # backend errors
```
