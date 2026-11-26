# OBSERVABILITY PROGRESS — Cloud Native Chat Platform

> **Handoff document between AI sessions.** Read this file FIRST in a new session, then
> check live cluster/ArgoCD status against it and resume from "Exact next action".
> Never repeat a phase marked DONE.

| Field | Value |
|---|---|
| Last updated | 2026-11-26 |
| Branch | `restore-kind-gitops` (local HEAD == origin, `e9916ec`) |
| Cluster | Kind, 1 node `chatapp-cluster-control-plane`, Kubernetes v1.33.1, containerd 2.1.1 |
| Host | AWS EC2 Ubuntu, 2 vCPU / 7.7 GB RAM, no swap |
| **Current phase** | **PROJECT COMPLETE — all phases DONE 2026-11-26. Awaiting user approval to commit/push.** |

## Status overview

| Phase | State | Notes |
|---|---|---|
| 0 — Environment audit | DONE | See "Audit findings" |
| 1 — Deploy Grafana Loki | DONE | Already deployed by an earlier session; validated 2026-11-26, no changes required |
| 2 — Deploy Grafana Alloy | DONE | Fixed config, rolled out via ArgoCD, validated 2026-11-26 (no errors, no duplicates) |
| 3 — Grafana integration | DONE | Validated 2026-11-26 via Grafana API; datasource was already provisioned |
| 4 — End-to-end log validation | DONE | See "PHASE 4" section below |
| 5 — Documentation | DONE | README.md + deploy/README.md updated |

## Important context (read this first)

- `OBSERVABILITY_PROGRESS.md` did **not** exist at the start of this session (2026-11-26). An
  earlier session had left uncommitted, partially working work behind. A targeted audit was done
  instead of restarting the project.
- ArgoCD `Application` manifests in `deploy/argocd/` are applied **directly** with
  `kubectl apply -f deploy/argocd/<name>.yaml` (the documented bootstrap workflow in
  `deploy/README.md`). `loki.yaml` and `alloy.yaml` reference public Helm charts with inline
  values, so **a `kubectl apply` of the Application file is enough for the cluster to pick up a
  change — no git push required** for those two. Git commit is still required for persistence
  and needs user approval.
- Grafana admin login comes from secret `grafana-admin-credentials` (namespace `monitoring`),
  **not** `admin`/`admin123` as the stale `deploy/README.md` claims. To call the Grafana API
  without printing the password, run curl **inside the Grafana pod** using its own env vars:
  ```bash
  kubectl -n monitoring exec deploy/monitoring-stack-grafana -c grafana -- sh -c \
    'curl -s -u "$GF_SECURITY_ADMIN_USER:$GF_SECURITY_ADMIN_PASSWORD" http://localhost:3000/api/health'
  ```
- The Loki and Grafana images contain no `curl`/`wget`. Reach them from the Grafana pod:
  `kubectl -n monitoring exec deploy/monitoring-stack-grafana -c grafana -- curl -s http://loki.monitoring.svc.cluster.local:3100/ready`
- On this Kind node the kubelet log files are **real files** (not symlinks) at
  `/var/log/pods/<ns>_<pod>_<uid>/<container>/<N>.log`, mode `0640 root:root`.
  `/var/log/containers/*.log` are symlinks to those files.
  ⇒ Mounting hostPath `/var/log` is sufficient for Alloy; Alloy must run as root (`runAsUser: 0`).

## PHASE 0 — AUDIT FINDINGS (DONE, nothing was modified)

### What already works (verified live)

| Component | Status |
|---|---|
| ArgoCD | `chatapp`, `grafana-secret`, `loki`, `monitoring-stack` Synced + Healthy; `alloy` Synced + **Progressing** (crashloop) |
| kube-prometheus-stack 69.8.2 | Prometheus, Grafana 11.5.2 (`database: ok`), Alertmanager, operator, kube-state-metrics, node-exporter all Running |
| Prometheus targets | 18 active, **14 up**. 4 down are the standard Kind control-plane endpoints (`kube-controller-manager`, `kube-etcd`, `kube-proxy`, `kube-scheduler` — connection refused). Pre-existing, unrelated to logging, NOT changed. |
| Grafana datasources (API) | `Prometheus` (uid `prometheus`, default), `Alertmanager` (uid `alertmanager`), `Loki` (uid `loki`, url `http://loki.monitoring.svc.cluster.local:3100`, non-default) |
| Loki | chart `loki` 7.7.0 → image 3.6.11, SingleBinary, `loki-0` Running 1/1, `/ready` → `ready` |
| Loki storage | PVC `storage-loki-0` 5Gi, StorageClass `standard` (local-path-provisioner), Bound |
| Loki Service | `loki` ClusterIP, ports 3100/9095 — internal only, no Ingress |
| Capacity | Node requests: CPU 1935m (**96%** of 2 vCPU), memory 2686Mi (34%). Alloy pod is already scheduled, so no new pod needs to fit. |

### What is broken / missing

1. **Alloy is crash-looping** (`alloy-wjzhv` 1/2, `CrashLoopBackOff`, 120+ restarts).
   Root cause (from previous container logs):
   ```
   Error: /etc/alloy/config.alloy:3:1: cannot find the definition of component name "loki.source.kubernetes_logs"
   Error: could not perform the initial load successfully
   ```
   `loki.source.kubernetes_logs` is an **experimental** component, but the chart starts Alloy with
   `--stability.level=generally-available` (`alloy.stabilityLevel` default), so it is not
   registered. The old config also never mounted the pod-resources socket that component needs.
   **Fix chosen:** replace it with the all-GA pipeline
   `discovery.kubernetes` → `discovery.relabel` → `local.file_match` → `loki.source.file` →
   `loki.process` → `loki.write`. No experimental stability level required.
2. **No logs are reaching Loki** (nothing pushes) — to be re-verified after the Alloy fix.
3. **Application metrics are NOT scraped** (pre-existing gap, outside the logging objective):
   - No `ServiceMonitor` exists in namespace `chat-app`; `count(chatapp_http_requests_total)` = empty in Prometheus.
   - The **live** `chatapp` Application uses `helm.valueFiles: ["values-ec2.yaml"]`, and at the
     committed revision `values-ec2.yaml` has `metrics.serviceMonitor.enabled: false`, which
     overrides `true` from `values.yaml`.
   - An earlier session already changed it to `enabled: true` locally (uncommitted,
     `helm/chat-app/values-ec2.yaml`). It only takes effect after **commit + push** to
     `restore-kind-gitops` ⇒ **needs user approval**. Not done.
4. **Repo/cluster drift in `deploy/argocd/chat-app.yaml`**: the file says
   `valueFiles: [values.yaml, values-kind.yaml]` but the live Application uses `values-ec2.yaml`.
   Re-applying that file per `deploy/README.md` would switch the app to the local-Kind values
   (traefik, `chat-app.local`). Not modified — reported to user only.
5. `deploy/README.md` is stale: says Loki + Promtail (`loki-stack` chart) and `admin`/`admin123`.

### Uncommitted work inherited from the earlier session (left as-is)

| File | Git state | Note |
|---|---|---|
| `deploy/argocd/loki.yaml` | modified | `loki-stack` → `loki` 7.7.0 SingleBinary. Live app matches it. |
| `deploy/argocd/alloy.yaml` | untracked | Contains the broken config — **edited in Phase 2**. |
| `deploy/argocd/observability-dashboards.yaml` | untracked | ArgoCD app pointing at GitHub path `deploy/monitoring/dashboards` on this branch. **Not applied.** Only works after commit + push. Deferred (dashboards are out of the core scope). |
| `deploy/monitoring/dashboards/chatapp-observability-dashboard.yaml` | untracked | Dashboard for app metrics. Deferred, same reason. |
| `helm/chat-app/values-ec2.yaml` | modified | `metrics.serviceMonitor.enabled: true` (see finding 3). |

### Existing public exposure (pre-existing, not changed)

Ingresses: `grafana.54.166.64.251.nip.io` (Grafana), `argocd.54.166.64.251.nip.io`,
`chat.54.166.64.251.nip.io`. Grafana was already exposed before this work; no new public
endpoints were created. **Loki and Alloy stay ClusterIP-only.**

### RBAC already present (sufficient for the GA pipeline)

ClusterRole `alloy` + ClusterRoleBinding `alloy` → ServiceAccount `monitoring/alloy`:
`get,list,watch` on `pods`, `pods/log`, `namespaces`, `nodes`, `services`, `endpoints`, … — enough
for `discovery.kubernetes` with `role = "pod"`. No extra RBAC needed.

## PHASE 1 — LOKI (DONE: validated 2026-11-26, no changes required)

Validation results (all live checks):

- Pod `loki-0` (StatefulSet, chart `loki` 7.7.0 → image `grafana/loki:3.6.11`, SingleBinary): `1/1 Running`, **0 restarts**.
- Real usage: 5m CPU / 53–81Mi against limits 300m CPU / 512Mi.
- Zero `level=error`/`level=warn` lines in pod logs.
- `GET http://loki.monitoring.svc.cluster.local:3100/ready` → `ready` (tested from the Grafana pod).
- `/loki/api/v1/labels` responds (`status: success`); compactor retention runs succeed (`loki_compactor_apply_retention_operation_total{status="success"}` increments).
- Storage: PVC `storage-loki-0` (5Gi, class `standard`) bound; on-node dir
  `/var/local-path-provisioner/pvc-bf1057bb-…_monitoring_storage-loki-0` holds
  `chunks/ compactor/ rules/ tsdb-shipper-active/ tsdb-shipper-cache/ wal/`, total usage 156K (empty before ingestion).
- Service `loki` is ClusterIP-only; **no Ingress references Loki anywhere** (checked `kubectl get ingress -A`).

## PHASE 2 — ALLOY (DONE: fixed, rolled out and validated 2026-11-26)

### Files modified
- `deploy/argocd/alloy.yaml` (uncommitted; live cluster already updated via `kubectl apply`):
  1. Replaced the broken config (`loki.source.kubernetes_logs`, experimental ⇒ unregistered
     under `--stability.level=generally-available`) with an all-GA pipeline:
     `discovery.kubernetes (role=pod)` → `discovery.relabel` → `local.file_match`
     → `loki.source.file` → `loki.process (stage.cri, label_drop filename)` → `loki.write`.
  2. Labels sent to Loki: `namespace, pod, container, node, app, stream` (`app` = pod label
     `app.kubernetes.io/name` falling back to `app`; `filename` dropped to avoid stream churn).
  3. Per-container file targets via glob `/var/log/pods/*<pod-uid>/<container>/*.log`; port
     meta-labels dropped + `__address__` set to node name so multi-port containers collapse into
     ONE tailer (no duplicate logs).
  4. Alloy's own pods excluded (`app="alloy"` dropped) — no feedback loop.
  5. Added `controller.volumes.extra` hostPath `/var/lib/alloy` (DirectoryOrCreate) mounted at
     `/tmp/alloy` (chart default `--storage.path`): read positions now survive container
     restarts/pod recreation. Without this, every restart re-read all files → duplicate
     ingestion of up to 7 days of logs into Loki.

### Deployment steps executed
```bash
kubectl apply -f deploy/argocd/alloy.yaml
kubectl -n argocd annotate application alloy argocd.argoproj.io/refresh=hard --overwrite
# (ArgoCD's periodic refresh took >2 min; hard refresh forces immediate reconcile)
# Seed positions before the second rollout so no re-read burst happened:
kubectl -n monitoring cp alloy-wjzhv:/tmp/alloy/loki.source.file.pod_logs/positions.yml /tmp/positions.yml -c alloy
docker exec chatapp-cluster-control-plane mkdir -p /var/lib/alloy/loki.source.file.pod_logs
docker cp /tmp/positions.yml chatapp-cluster-control-plane:/var/lib/alloy/loki.source.file.pod_logs/positions.yml
kubectl apply -f deploy/argocd/alloy.yaml   # second rollout (persistent storage)
kubectl -n argocd annotate application alloy argocd.argoproj.io/refresh=hard --overwrite
```

### Validation results
- Pod `alloy-r9qsn` (DaemonSet `alloy`, image `grafana/alloy:v1.22.0`): `2/2 Running` (alloy + config-reloader), 7m CPU / 90Mi.
- ArgoCD app `alloy`: **Synced / Healthy**.
- Alloy logs: **0 errors, 0 warnings**; tailer started on all pod log files.
- RBAC: chart-created ClusterRole `alloy` covers pods/nodes/services/endpoints/etc. (get,list,watch) — sufficient.
- Discovery: Loki `label/{namespace,pod,container,app,node,stream}/values` all populated across
  namespaces argocd, chat-app, ingress-nginx, kube-system, local-path-storage, monitoring.
- **Not-Ready pods are collected**: temporary never-Ready test pod's stdout reached Loki within
  seconds while the pod was 0/1 (test pod deleted afterwards).
- **No duplicates**: for a fixed window, container stdout line counts == Loki counts exactly for
  multi-port containers (loki 226=226, grafana 3=3, backend 90=90, mongodb 210=210, frontend
  100=100, kindnet 120=120).
- **Restart safety**: after the persistent-storage rollout (positions seeded first), frontend
  counts matched exactly (25=25), node file `/var/lib/alloy/.../positions.yml` keeps updating,
  and the new pod logged 0 errors — no re-read burst, no "timestamp too old" 400s.
- One-time note: the FIRST start (before persistence) re-read files from position 0 and Loki
  rejected entries older than 168h → 22 `status=400 timestamp too old` lines in an 8-second
  window, then silence. That is expected bootstrap behaviour, resolved by the persistent
  positions dir.

## PHASE 3 — GRAFANA INTEGRATION (DONE: validated 2026-11-26, no changes required)

The Loki datasource is provisioned **persistently** by the existing `deploy/argocd/monitoring.yaml`
(`grafana.additionalDataSources` → uid `loki`, url `http://loki.monitoring.svc.cluster.local:3100`,
`maxLines: 1000`) — same ArgoCD app as Prometheus/Grafana, no new Grafana instance, Prometheus
datasource untouched.

Validation results (all through the Grafana API, using the pod's own admin env vars):

- `GET /api/health` → `{"database":"ok","version":"11.5.2"}`.
- `GET /api/datasources/uid/loki/health` → `{"message":"Data source successfully connected.","status":"OK"}`.
- `GET /api/datasources/uid/prometheus/health` → `{"status":"OK","message":"Successfully queried the Prometheus API."}`.
- Query through the Grafana datasource proxy (exactly what Explore calls):
  - Loki `query_range {app="backend"}` → returns real log lines with labels
    `{app, container, detected_level, namespace, node, pod, service_name, stream}`.
  - Prometheus `query count(up==1)` → `14` targets up.
- Datasource list confirmed: Prometheus (default), Alertmanager, Loki — nothing overwritten.
- All pre-existing Grafana dashboards (kube-prometheus-stack set) still listed via `/api/search`.

Note: datasource health-check warnings seen previously in Grafana UI (per old README section
"7) Loki datasource health-check warning") no longer occur.

## PHASE 4 — END-TO-END LOG VALIDATION (DONE 2026-11-26)

### Labels actually present in Loki (verified, not assumed)
`namespace, pod, container, app, node, stream, service_name` (+ `detected_level` added by Loki at
query time; `__stream_shard__` is Loki-internal). `app` = pod label `app.kubernetes.io/name`
falling back to plain `app` (chat-app pods use `app=backend` etc.).

### What was validated

1. **Ingress activity → Loki**: curl through `http://chat.54.166.64.251.nip.io` (frontend `/`,
   backend `/api/health`, `/api/messages/users/someid`, socket.io polling). Within seconds, Loki
   contained backend request lines (`GET /api/messages/users/someid`, `GET /api/health`),
   frontend nginx access lines, and mongodb connection lines.
2. **Error-level lines queryable** (backend logs are plain text; `stream` is the reliable signal):
   - `POST /api/auth/login` with malformed JSON → HTTP 500 →
     `GLOBAL ERROR HANDLER: SyntaxError: Expected property name or '}' in JSON…` on **stderr**.
   - `GET /api/messages/users` with `Cookie: jwt=garbage.token` → HTTP 500 →
     `Error in protectRoute middleware:  jwt malformed` on **stdout** (note: middleware reads the
     `jwt` cookie, not `token`; with NO cookie it 401s *without* logging).
   - Pre-existing app error on every static-file request: `Error: ENOENT: … '/frontend/dist/index.html'` on stderr (backend not built to serve frontend here; NOT a logging issue).
3. **MongoDB logs**: JSON lines (`{"t":{"$date":…},"s":"I","c":"NETWORK",…}`) present.
4. **Redis logs**: present (7 startup lines from its last restart, 25 Nov 06:40). Redis only logs
   at startup, so recent-window queries are empty by design — use a 24h window.
5. **Pod restart auto-discovery**: restarted `deploy/backend`. NOTE: the rolling update initially
   stuck with `FailedScheduling: Insufficient cpu` (node CPU requests were at 96% of 2000m and a
   rolling update needs 2 backend pods' requests simultaneously). Deleting the old pod (graceful,
   stateless app) freed its 100m and the rollout completed. Alloy discovered the NEW pod
   `backend-68f4b47d6f-cvkbd` automatically — startup sequence
   (`server is running on PORT:5001`, `MongoDB connected`, `Redis publisher/subscriber connected`)
   plus new request/error lines appeared in Loki within seconds, with **zero Alloy changes**.
   Old pod logs remain queryable under the old `pod` label.
6. **No duplicate ingestion** after any of the restarts (positions dir persisted at
   `/var/lib/alloy` on the node).

### Working LogQL queries (for Grafana Explore — datasource "Loki")

```logql
{namespace="chat-app", app="backend"}                      // all backend logs
{namespace="chat-app", app="frontend"}                     // frontend (nginx access logs)
{namespace="chat-app"}                                     // everything in chat-app
{namespace="monitoring"}                                   // monitoring stack logs
{namespace="chat-app", app="backend", stream="stderr"}     // backend errors (plain-text app)
{namespace="chat-app", app="backend"} |= "Error"           // lines mentioning Error
{namespace="chat-app", app="mongodb"}                      // MongoDB (JSON lines)
{namespace="chat-app", app="mongodb"} | json               // parse MongoDB JSON fields
{namespace="chat-app", app="redis"}                        // Redis (startup lines only)
{namespace="ingress-nginx", container="controller"}        // ingress-nginx access logs
{pod=~"backend-.*"}                                        // by pod pattern (survives restarts)
sum by (app) (count_over_time({namespace="chat-app"}[5m])) // log volume per app
rate({namespace="chat-app", app="backend"} |= "Error" [5m])  // error rate
```

Note: prefer `pod=~"backend-.*"` over an exact pod name in saved queries — pod names change on
restart, `app`/`container` labels are stable.

## Known errors

- None currently. (Historical: experimental-component config error and bootstrap 400s — both resolved, see Phase 2.)
- Environmental note: a full rolling restart of `deploy/backend` cannot schedule while the old
  pod runs (CPU requests 96%/2000m on this node). Delete the old pod first or lower requests.

## PHASE 5 — DOCUMENTATION (DONE 2026-11-26)

- `README.md`: Promtail → Grafana Alloy across all 15 mention sites; logging-pipeline diagram
  (`discovery.kubernetes → local.file_match → loki.source.file`); "Centralized logs (Loki + Grafana
  Alloy)" section with the validated LogQL list; Access Grafana section now documents the ingress
  URL (`grafana.54.166.64.251.nip.io`) and sealed-secret credentials (removed stale
  `admin`/`admin123`); troubleshooting item 7 updated (health check now passes); achievements and
  validation checklist updated with `alloy` app.
- `deploy/README.md`: `loki-stack` rows → `loki` 7.x single binary + new `alloy.yaml` row; added
  `kubectl apply -f deploy/argocd/alloy.yaml` to the bootstrap snippet; corrected Grafana
  credentials instructions (sealed secret); LogQL examples use the actual labels.
- Architecture diagram: existing mermaid/ASCII diagrams updated in place (no new image files).

## COMPLETION CRITERIA (all verified live 2026-11-26)

- [x] Existing Prometheus healthy — `prometheus-monitoring-…-0` 2/2 Running; 14/18 targets up (4 down are the standard Kind control-plane endpoints, pre-existing)
- [x] Existing Grafana healthy — 3/3 Running, `/api/health` → `database: ok`
- [x] Loki deployed and healthy — `loki-0` 1/1 Running, `/ready` ok, compactor retention succeeding
- [x] Alloy deployed and healthy — `alloy-r9qsn` (DaemonSet) 2/2 Running, 0 errors/warnings
- [x] Alloy collects Kubernetes container logs — all 6 namespaces
- [x] Logs forwarded to Loki — content-verified (counts match container stdout exactly)
- [x] Loki configured as Grafana datasource — provisioned via `monitoring.yaml`, health check OK
- [x] Grafana Explore displays actual application logs — verified through the Grafana datasource proxy API (the same API the Explore UI calls)
- [x] Kubernetes metadata available — `namespace, pod, container, app, node, stream, service_name`
- [x] MongoDB and Redis logs available — MongoDB JSON lines; Redis startup lines (Redis only logs at startup)
- [x] New application pods discovered automatically — backend restart test passed (`backend-68f4b47d6f-cvkbd`)
- [x] Existing Prometheus dashboards and datasource remain functional — `/api/search` lists all, proxy query returns data
- [x] ArgoCD applications Synced and Healthy — `chatapp`, `grafana-secret`, `loki`, `alloy`, `monitoring-stack` all Synced/Healthy
- [x] README documentation updated (README.md + deploy/README.md)
- [x] OBSERVABILITY_PROGRESS.md contains final implementation and validation results

## Exact next action

> **USER DECISION REQUIRED (no further technical work pending):**
> 1. Review and approve commit + push of: `README.md`, `deploy/README.md`,
>    `deploy/argocd/loki.yaml` (from earlier session), `deploy/argocd/alloy.yaml` (new),
>    `helm/chat-app/values-ec2.yaml` (earlier session: enables app ServiceMonitor after push),
>    `OBSERVABILITY_PROGRESS.md` (new). Until pushed, the cluster state (already correct) and git
>    will drift; `loki`/`alloy` ArgoCD apps have inline values so the cluster does NOT depend on
>    the push to keep working — but the repo must be pushed for durability.
> 2. `deploy/argocd/observability-dashboards.yaml` + `deploy/monitoring/dashboards/…` (earlier
>    session, untracked): optional extras; they only work after push (Git-source app). Deferred —
>    not part of the core logging pipeline.
> 3. Known drift: repo file `deploy/argocd/chat-app.yaml` says `valueFiles: [values.yaml,
>    values-kind.yaml]` but the LIVE `chatapp` app uses `values-ec2.yaml`. Re-applying the repo
>    file as-is would break the EC2 ingress. Align the file with the live spec before any push
>    (recommended: make the repo file match the live spec).

## Commands already executed (key ones)

```bash
# Phase 0 audit
kubectl get nodes -o wide; kubectl get ns; kubectl get pods -A -o wide
kubectl get applications -n argocd
kubectl -n monitoring logs -l app.kubernetes.io/name=alloy -c alloy --previous --tail=40
kubectl -n argocd get application chatapp -o jsonpath='{.spec.source}'        # live valueFiles
kubectl get servicemonitor,podmonitor -A
kubectl get pvc -A; kubectl get svc -n monitoring; kubectl get ingress -A
kubectl describe node chatapp-cluster-control-plane                            # allocated resources
docker exec chatapp-cluster-control-plane sh -c 'ls /var/log/pods; du -sh /var/log/pods'   # 36M total
helm show values alloy --repo https://grafana.github.io/helm-charts --version 1.16.0
```

## Configuration decisions

| Decision | Reason |
|---|---|
| Alloy chart `alloy` 1.16.0, DaemonSet, `stabilityLevel` left at `generally-available` | Only GA components are used; no experimental flags |
| Alloy reads `/var/log/pods` via `local.file_match` (not `loki.source.kubernetes_logs`) | GA + officially documented approach; works on Kind with just `/var/log` mounted |
| One file target per container: glob `/var/log/pods/*<pod_uid>/<container>/*.log` | Guarantees each file is tailed exactly once (no duplicates); avoids the shared-glob pitfall |
| Alloy does not collect its own pods | Avoids a log feedback loop (Alloy errors about pushing to Loki would be ingested by Alloy) |
| Loki: no changes | Existing config already matches requirements (single binary, 5Gi PVC, 168h retention, internal only) |
