# Deployment layout

| Path | Purpose |
|------|---------|
| `deploy/argocd/chat-app.yaml` | ArgoCD app — Helm chart at `helm/chat-app` |
| `deploy/argocd/monitoring.yaml` | ArgoCD app — Prometheus + Grafana (`kube-prometheus-stack`) |
| `deploy/kind/kind-config.yaml` | Kind cluster with host ports 80/443 |
| `deploy/secrets/` | Kubeseal cert + re-sealing instructions (cert is gitignored) |

## Apply GitOps apps

```bash
kubectl apply -f deploy/argocd/chat-app.yaml
kubectl apply -f deploy/argocd/monitoring.yaml
```

## Monitoring (port-forward)

```bash
kubectl get pods -n monitoring
kubectl port-forward -n monitoring svc/monitoring-stack-grafana 3000:80
kubectl port-forward -n monitoring svc/monitoring-stack-kube-prom-prometheus 9090:9090
```

- Grafana: http://localhost:3000 (`admin` / `admin123`)
- Prometheus: http://localhost:9090
