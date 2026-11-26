# PROJECT UPGRADE PROGRESS — Cloud Native Chat Platform

> **Handoff document between AI sessions.** Read FIRST in a new session, verify live state against
> it, resume from "Exact next action". Never repeat a phase marked DONE.
> Companion file: `OBSERVABILITY_PROGRESS.md` (logging pipeline — completed 2026-11-26; read it for
> Loki/Alloy/Grafana details, credentials handling and LogQL queries).

| Field | Value |
|---|---|
| Last updated | 2026-11-26 |
| Branch | `restore-kind-gitops` @ `e9916ec` (local == origin) + uncommitted changes from observability work |
| Cluster | Kind `chatapp-cluster-control-plane` (K8s v1.33.1, 1 node, 2 vCPU / 7.7 GB) on AWS EC2 Ubuntu |
| **Current phase** | **PHASE 3 — DONE (app metrics instrumentation + Prometheus scrape validated). Starting PHASE 4 (deployment of new backend image)** |

## Status overview

| Phase | State | Notes |
|---|---|---|
| 0 — Audit | DONE | See "Audit findings" |
| 1 — README / deployment docs | DONE | README.md rewritten for EC2 + Kind reality; port-forward demoted to optional troubleshooting |
| 2 — EC2 endpoint automation | DONE | `scripts/update-ec2-endpoints.sh` created + applied; `deploy/ingress/argocd-ingress.yaml` created under Git; systemd unit reference documented |
| 3 — App metrics audit & instrumentation | DONE | 7 metrics total: 3 pre-existing + 4 new. Pre-existing metrics (chatapp_http_requests_total, chatapp_http_request_duration_seconds, chatapp_socket_connections_active) confirmed working in Prometheus. 4 new metrics (user_logins_total, user_registrations_total, messages_sent_total, registered_users_total) are defined in code but unavailable in the running image because the deployed backend image predates the instrumentation. |
| 4 — Dashboards A & B (app, user activity) | IN PROGRESS | Dashboard A: all 8 panels validated with live Prometheus data (total 4237 requests, rate 0.148/s, p95 latency 4.75ms, backend up, 2xx flowing). Dashboard B: 3 pre-existing metrics work (active users=1, socket connections=1, ready); 4 new metrics unavailable until updated backend image deploys. Panels depending on the 4 new metrics currently display "UNAVAILABLE (no series)" — not a query bug, image deployment needed. |
| 5 — Dashboards C & D (infra, logs) | DONE | Both fully validated against live data (validated PromQL + LogQL panel queries, all returning real data). |
| 6 — End-to-end testing & final docs | PENDING | |

## PHASE 0 — AUDIT FINDINGS (2026-11-26, read-only)

### Live environment (verified)

- ArgoCD apps: `chatapp`, `grafana-secret`, `loki`, `alloy`, `monitoring-stack` — all **Synced/Healthy**.
- All pods Running across `chat-app`, `monitoring`, `argocd`, `ingress-nginx`, `kube-system`, `local-path-storage`.
- Ingresses (verified live):
  - `chat-app/chat-app` → host `chat.54.166.64.251.nip.io`, class nginx — **ArgoCD-managed** (helm `values-ec2.yaml`, selfHeal: true)
  - `monitoring/grafana-ingress` → `grafana.54.166.64.251.nip.io` — **manually applied** (file `deploy/ingress/grafana-ingress.yaml`, no ArgoCD app)
  - `argocd/argocd-ingress` → `54.166.64.251.nip.io` (argocd-server) — **manually applied, NO repo file exists (drift)**
- Public IP: `54.166.64.251` (changes on EC2 stop/start — instance has no Elastic IP).

### IP hardcoding audit (complete list)

| Location | Object | Managed by | Update path |
|---|---|---|---|
| `helm/chat-app/values-ec2.yaml:55` (`ingress.host`) | chat-app Ingress | ArgoCD `chatapp` app (pulls from GitHub) | git change + push + ArgoCD sync; live patch alone is **reverted by selfHeal** |
| `deploy/ingress/grafana-ingress.yaml` | grafana Ingress | nothing (manual) | edit file + `kubectl apply` (no conflict) |
| live only: `argocd/argocd-ingress` | argocd Ingress | nothing (manual, no file!) | **create repo file** + `kubectl apply` |
| `README.md` | docs | — | edit |
| `OBSERVABILITY_PROGRESS.md` | docs | — | edit |

### Application metrics audit (`backend/src/lib/metrics.js`, middleware, socket.js)

Existing (all real, verified in code):
- `chatapp_http_requests_total` (counter; `method, route, status_code`) + `chatapp_http_request_duration_seconds` (histogram) via `middleware/metrics.middleware.js`
- `chatapp_socket_connections_active` (gauge) and `chatapp_active_users` (gauge — "users with an active socket session", i.e. distinct authenticated socket sessions) via periodic refresh in `lib/socket.js` (per-instance values; Prometheus aggregates across replicas)
- default Node/process metrics with `chatapp_` prefix

Missing (candidates, low-cardinality, no user IDs): `chatapp_user_logins_total`, `chatapp_user_registrations_total`, `chatapp_messages_sent_total`, `chatapp_registered_users_total` (gauge, periodic MongoDB count — NOT the same as active users; documented semantics required).

**CRITICAL DEPENDENCY (D3):** Prometheus is NOT scraping app metrics right now — no ServiceMonitor exists in `chat-app` because the live `values-ec2.yaml` has `metrics.serviceMonitor.enabled: false`. An uncommitted local change flips it to `true`. Dashboards A/B show no app data until: commit+push → ArgoCD sync. Backend code changes additionally require CI image build (short-SHA tag) + `backend.tag` bump in `values-ec2.yaml`.

### CI/CD (`.github/workflows/cicd.yml`)

- Triggers: push to `main` / `restore-kind-gitops` (paths-ignore `deploy/**`, `helm/**`), tags, PRs, manual.
- Builds backend + frontend images, tags with **short commit SHA** (and `latest` in publish job), pushes to Docker Hub (`secrets.DOCKERHUB_NAMESPACE`). Gitleaks scan + Trivy scan included.
- Deploy = update image `tag` in `helm/chat-app/values-ec2.yaml` → ArgoCD syncs (GitOps; there is no auto CD step in the workflow).

### Dashboards / provisioning status

- Grafana pod already runs the dashboard+datasource sidecars (`grafana-sc-dashboard`, `grafana-sc-datasources`) → ConfigMaps labelled `grafana_dashboard: "1"` in `monitoring` are auto-provisioned.
- `deploy/monitoring/dashboards/chatapp-observability-dashboard.yaml` (untracked, prior session): ConfigMap draft with PromQL panels (`chatapp_http_requests_total` etc.) — usable as a base, needs review/completion.
- `deploy/argocd/observability-dashboards.yaml` (untracked, prior session): ArgoCD app for path `deploy/monitoring/dashboards` — **requires push to function**. Same manifests can be applied manually for immediate validation without GitOps conflicts.

### Repo/cluster drift (carried over from observability work — decision needed at commit time)

1. `deploy/argocd/chat-app.yaml` (repo) says `valueFiles: [values.yaml, values-kind.yaml]`; **live** app uses `values-ec2.yaml`. Re-applying the repo file as-is would break the EC2 ingress. → align repo file with live spec before any push.
2. Uncommitted changes awaiting approval: `README.md`, `deploy/README.md`, `deploy/argocd/loki.yaml`, `deploy/argocd/alloy.yaml`, `helm/chat-app/values-ec2.yaml` (serviceMonitor flip), `OBSERVABILITY_PROGRESS.md`, untracked `deploy/argocd/alloy.yaml`, `deploy/argocd/observability-dashboards.yaml`, `deploy/monitoring/dashboards/`.
3. `deploy/argocd/traefik.yaml` — stale ArgoCD app for traefik (cluster actually uses ingress-nginx; traefik app not applied). Leave untouched, note in README that it's unused/optional.
4. `argocd-ingress` must be brought under repo control (`deploy/ingress/argocd-ingress.yaml`) during Phase 2.

## PROPOSED PLAN (presented to user)

**Objective 2 design (endpoint automation):**
- `scripts/update-ec2-endpoints.sh` (idempotent): detect IP via `curl -s https://checkip.amazonaws.com` (fail hard if empty/non-IP); generate `<ip>.nip.io` hostnames; update exactly three config files (`helm/chat-app/values-ec2.yaml`, `deploy/ingress/grafana-ingress.yaml`, new `deploy/ingress/argocd-ingress.yaml`) by regex-replacing only `*.nip.io` host lines (no unrelated IPs touched); `kubectl apply` grafana+argocd ingresses (safe, not ArgoCD-managed); patch chat-app ingress live (immediate availability); then — GitOps consistency — report git diff and require explicit `--push` flag (or interactive confirm) to commit+push so ArgoCD selfHeal converges instead of reverting; verify hostnames resolve + HTTP 200; print final URLs.
- Boot automation: systemd unit `chatapp-endpoints.service` runs the script at boot (`After=network-online.target`); **installation on the host only after user approval** (system-level change). Without push, ArgoCD would revert the chat-app ingress — the unit therefore supports `AUTO_PUSH=1` (user enables consciously after approving automated pushes) OR falls back to live-patch + notification.
- Honest constraint stated to user: chat-app hostname persistence REQUIRES a git push (ArgoCD source of truth); local-only steps cover grafana/argocd endpoints and immediate availability. Elastic IP alternative explained: AWS charges ~$0.005/hr for in-use public IPv4 (auto-assigned included); EIP adds stability across stop/start, not extra cost vs. today's IP beyond the same IPv4 charge; free tier may cover 750h/mo — user decision, not implemented by default.

**Objective 3/4 design (metrics + dashboards A/B):** add minimal counters (`logins`, `registrations`, `messages_sent` — increment only after success) and `chatapp_registered_users_total` gauge (periodic MongoDB estimated count, distinct from active users; semantics documented in README). Socket gauges stay as-is (per-instance, aggregated by Prometheus). Follow existing conventions in `metrics.js`/`socket.js`/`middleware`. Deployment requires push → CI → tag bump (approval-gated).

**Objective 3 dashboards:** 4 dashboards (A Application Overview, B User Activity, C Kubernetes Infra, D Logs & Errors) as `grafana_dashboard: "1"` ConfigMap manifests in `deploy/monitoring/dashboards/`; validate immediately via `kubectl apply` (sidecar provisions); the already-drafted ArgoCD app manages them post-push. Queries built ONLY from verified metrics/labels (PromQL from `metrics.js` audit; LogQL from `OBSERVABILITY_PROGRESS.md` labels).

## Configuration decisions

| Decision | Reason |
|---|---|
| Dashboards as ConfigMaps + sidecar (not helm-inline values) | Reproducible files in Git; works with existing kube-prometheus-stack sidecar; manual apply == ArgoCD apply for validation-before-push |
| Endpoint automation keeps 3 explicit files (no templating engine) | Simplest source of truth; sed-replace of nip.io host lines only; avoids new tooling |
| `--push` flag on script; no auto-push without user approval | Safety rule; boot unit's AUTO_PUSH stays opt-in |
| Backend instrumentation: counters post-success, gauge via periodic DB count, no user-ID labels | Task requirements + low cardinality |

## Exact next action

> PHASE 1: rewrite README for EC2 + Kind reality (sections A–G per task; WSL/localhost port-forward demoted to optional troubleshooting; fresh-setup + restart-recovery + troubleshooting sections; reuse updated observability sections from the observability work). Then update this file and proceed to Phase 2.

## Commands already executed (key ones — Phase 0)

```bash
grep -rn -E '54\.166\.64\.251|nip\.io' (repo sweep, 5 config/doc locations found)
sed -n / grep on .github/workflows/cicd.yml, backend/src/lib/metrics.js, socket.js, ingress templates
kubectl -n argocd get ingress argocd-ingress -o jsonpath (provenance — manual, no repo file)
kubectl -n argocd get applications; kubectl get ingress -A
```
