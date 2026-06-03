# Deployment layout

| Path | Purpose |
|------|---------|
| `deploy/argocd/chat-app.yaml` | ArgoCD app — Helm chart at `helm/chat-app` |
| `deploy/argocd/monitoring.yaml` | Prometheus + Grafana (`kube-prometheus-stack`) |
| `deploy/argocd/loki.yaml` | Loki + Promtail (`loki-stack` chart) |
| `deploy/kind/kind-config.yaml` | Kind cluster with host ports 80/443 |
| `deploy/secrets/` | Kubeseal cert + re-sealing instructions (cert is gitignored) |

## Apply GitOps apps

```bash
kubectl apply -f deploy/argocd/chat-app.yaml
kubectl apply -f deploy/argocd/monitoring.yaml
kubectl apply -f deploy/argocd/loki.yaml
```

## Monitoring (port-forward)

```bash
kubectl get pods -n monitoring
kubectl port-forward -n monitoring svc/monitoring-stack-grafana 3000:80
kubectl port-forward -n monitoring svc/monitoring-stack-kube-prom-prometheus 9090:9090
```

- Grafana: http://localhost:3000 (`admin` / `admin123`) — **Explore → Loki** for logs, **Explore → Prometheus** for metrics
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

Example LogQL in Grafana (Loki):

```logql
{namespace="chat-app", pod=~"backend.*"}
```
