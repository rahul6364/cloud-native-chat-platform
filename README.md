# Real-Time Chat Application

A full-stack, cloud-native real-time chat application built with React, Node.js/Express, Socket.io, and MongoDB — packaged with **Helm**, deployed via **ArgoCD GitOps**, and hardened for production with autoscaling, observability, and security controls.

**Repository:** [rahul6364/cloud-native-chat-platform](https://github.com/rahul6364/cloud-native-chat-platform)

```bash
git clone https://github.com/rahul6364/cloud-native-chat-platform.git
cd cloud-native-chat-platform
```

## Table of Contents

* [Production Features](#production-features)
* [Introduction](#introduction)
* [Features](#features)
* [Tech Stack](#tech-stack)
* [Current Project Status](#current-project-status)
* [Production Architecture](#production-architecture)
* [GitOps Workflow](#gitops-workflow)
* [Observability Architecture](#observability-architecture)
* [Project Structure](#project-structure)
* [Environment Configuration](#environment-configuration)
* [Quick Start (Docker Compose)](#quick-start-docker-compose)
* [🚀 Kubernetes Deployment from Scratch](#-kubernetes-deployment-from-scratch)
    * [Step 1: Cluster Setup (Kind)](#step-1-cluster-setup-kind)
    * [Step 2: Core Infrastructure (Ingress & Secrets)](#step-2-core-infrastructure-ingress--secrets)
    * [Step 3: Option A - Helm Deployment](#step-3-option-a---helm-deployment)
    * [Step 3b: HPA, PDB, and Network Policies](#step-3b-hpa-pdb-and-network-policies)
    * [Step 4: Option B - GitOps Deployment (ArgoCD)](#step-4-option-b---gitops-deployment-argocd)
* [Load Testing & Autoscaling Validation](#load-testing--autoscaling-validation)
* [🌐 Accessing the Application](#-accessing-the-application)
* [📊 Monitoring & Observability](#-monitoring--observability)
* [Validation Checklist](#validation-checklist)
* [Issues Faced and Fixes](#issues-faced-and-fixes)
* [CI/CD Status](#cicd-status)
* [Project Achievements](#project-achievements)
* [Contributing](#contributing)
* [License](#license)

---

## Production Features

This project goes beyond a demo chat app — it implements patterns used in production Kubernetes environments:

| Category | Implementation |
|----------|----------------|
| **Packaging** | Helm chart (`helm/chat-app/`) with templated Deployments, Services, Ingress, HPA, PDB, NetworkPolicy, and SealedSecrets |
| **GitOps** | ArgoCD watches `main` and auto-syncs Helm values to the cluster |
| **Metrics** | Prometheus scrapes custom app metrics from `GET /metrics` via ServiceMonitor |
| **Dashboards** | Grafana with Prometheus and Loki datasources pre-configured |
| **Logging** | Loki + Promtail centralized log aggregation from all pods |
| **Autoscaling** | Horizontal Pod Autoscaler (HPA) on frontend and backend (2–5 replicas, 70% CPU target) |
| **Resilience** | Pod Disruption Budgets on frontend, backend, and MongoDB |
| **Security** | Network Policies restricting pod-to-pod traffic; Bitnami Sealed Secrets for credentials in Git |
| **Resources** | CPU/memory requests and limits on every workload |
| **Data layer** | MongoDB as a StatefulSet with persistent volume and headless service |

---

## Introduction

This project provides a scalable, production-style chat application with:

* JWT authentication with HTTP-only cookies
* Real-time messaging with Socket.io
* MongoDB persistence
* Containerized local development and Kubernetes deployment
* Full observability and GitOps delivery pipeline

---

## Features

* Real-time messaging with Socket.io
* JWT-based auth and protected routes
* Profile updates and online user presence
* React + TailwindCSS frontend
* Docker and Kubernetes support
* Helm-based deployment with GitOps (ArgoCD)
* Prometheus metrics, Grafana dashboards, and Loki centralized logging
* HPA autoscaling validated with k6 load testing

---

## Tech Stack

| Layer | Technologies |
|-------|--------------|
| **Backend** | Node.js, Express, Socket.io, MongoDB, prom-client |
| **Frontend** | React, TailwindCSS, Zustand, Vite |
| **Containerization** | Docker, Docker Compose |
| **Orchestration** | Kubernetes (Kind), ingress-nginx |
| **Packaging** | Helm |
| **GitOps / CD** | ArgoCD |
| **CI/CD** | GitHub Actions, Trivy, Gitleaks, CodeQL |
| **Observability** | Prometheus, Grafana, Loki, Promtail |
| **Secrets** | Bitnami Sealed Secrets |
| **Web Server** | Nginx (frontend container) |
| **Authentication** | JWT + HTTP-only cookies |
| **Load Testing** | k6 |

---

## Current Project Status

### Implemented & Validated

| Area | Status |
|------|--------|
| **Application** | Backend, frontend, and MongoDB containerized and deployable on Kind |
| **Local dev** | Docker Compose works at `http://localhost` |
| **Helm migration** | Raw K8s manifests migrated to `helm/chat-app/`; ArgoCD deploys from `main` |
| **GitOps** | ArgoCD auto-sync enabled for chat-app, monitoring, and Loki stacks |
| **MongoDB** | Migrated from Deployment → **StatefulSet** with headless service and PVC |
| **Health checks** | Backend `/health` returns `503` when MongoDB is disconnected; readiness/liveness probes on all workloads |
| **Security** | Bitnami Sealed Secrets for JWT and Cloudinary credentials in Git |
| **Production hardening** | HPA, PDBs, NetworkPolicies, resource requests/limits (via Helm values) |
| **HPA validation** | **Validated with k6** — backend scaled automatically from **2 → 3 replicas** when CPU exceeded the 70% threshold |
| **Prometheus metrics** | Custom application metrics successfully scraped via ServiceMonitor |
| **Grafana** | Dashboards and Explore views operational (Prometheus + Loki datasources) |
| **Loki + Promtail** | Centralized application logs collected and visible in Grafana Explore |
| **Observability stack** | End-to-end metrics + logs pipeline verified |
| **CI/CD** | GitHub Actions builds, scans (Trivy), pushes images, and updates Helm image tags |
| **Socket.io multi-replica** | Ingress cookie affinity + backend session affinity for sticky Socket.io sessions |
| **Payload support** | 10 MB request limits (Express + Nginx Ingress) for profile picture uploads |

---

## Production Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         Kind Cluster (chat-app.com)                     │
│                                                                         │
│  ┌──────────────┐     ┌─────────────────────────────────────────────┐  │
│  │  ArgoCD      │────▶│  Helm Chart (helm/chat-app)                 │  │
│  │  (GitOps)    │     │  ├── Frontend Deployment (Nginx + React)    │  │
│  └──────────────┘     │  ├── Backend Deployment (Node.js + Socket)  │  │
│                       │  ├── MongoDB StatefulSet                    │  │
│                       │  ├── Ingress (NGINX)                        │  │
│                       │  ├── HPA / PDB / NetworkPolicy              │  │
│                       │  └── SealedSecret                           │  │
│                       └─────────────────────────────────────────────┘  │
│                                         │                               │
│  ┌──────────────┐     ┌─────────────────▼───────────────────────────┐  │
│  │ Ingress NGINX│────▶│  /api, /socket.io → Backend                 │  │
│  │ (port 8080)  │     │  /              → Frontend                  │  │
│  └──────────────┘     └─────────────────────────────────────────────┘  │
│                                                                         │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │  monitoring namespace                                            │  │
│  │  ├── Prometheus  ← ServiceMonitor scrapes backend /metrics       │  │
│  │  ├── Grafana     ← dashboards + Explore (metrics + logs)         │  │
│  │  ├── Loki        ← log storage                                   │  │
│  │  └── Promtail    ← collects logs from all cluster pods           │  │
│  └──────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────┘
```

| Component | Role |
|-----------|------|
| **Frontend Deployment** | Serves React SPA via Nginx; proxies `/api` and `/socket.io` internally when accessed via service |
| **Backend Deployment** | REST API, Socket.io server, JWT auth, Prometheus `/metrics` endpoint |
| **MongoDB StatefulSet** | Persistent chat data with stable network identity |
| **Ingress NGINX** | Host-based routing (`chat-app.com`), WebSocket support, sticky sessions for Socket.io |
| **ArgoCD** | Watches Git repo; auto-syncs Helm chart and observability stacks |
| **Prometheus** | Scrapes Kubernetes and custom application metrics |
| **Grafana** | Visualization — dashboards, Explore, alerting |
| **Loki** | Centralized log aggregation and indexing |
| **Promtail** | DaemonSet that ships container logs to Loki |

---

## GitOps Workflow

Every push to `main` triggers a fully automated delivery pipeline:

```
Developer Push (main)
        │
        ▼
GitHub Actions CI
  ├── Gitleaks secret scan
  ├── ESLint
  ├── CodeQL static analysis
  ├── Docker Build (frontend + backend)
  ├── Trivy container scan (CRITICAL/HIGH)
  └── Docker Hub Push (SHA tag + latest)
        │
        ▼
Helm Values Update
  └── helm/chat-app/values.yaml image tags bumped to new SHA
        │
        ▼
Git commit + push to main  [skip ci]
        │
        ▼
ArgoCD detects diff
  ├── chat-app      → syncs Helm chart
  ├── monitoring-stack → Prometheus + Grafana
  └── loki          → Loki + Promtail
        │
        ▼
Kubernetes Rollout
  └── Rolling update of frontend and backend pods
```

Pipeline definition: `.github/workflows/cicd.yml`

ArgoCD applications:

| App | Manifest | Deploys |
|-----|----------|---------|
| `chat-app` | `deploy/argocd/chat-app.yaml` | Application Helm chart |
| `monitoring-stack` | `deploy/argocd/monitoring.yaml` | Prometheus + Grafana |
| `loki` | `deploy/argocd/loki.yaml` | Loki + Promtail |

---

## Observability Architecture

### Metrics path

```
Application (Node.js)
        │
        ▼
   prom-client  →  exposes GET /metrics
        │
        ▼
   ServiceMonitor  →  discovers backend Service (label: app=backend)
        │
        ▼
   Prometheus  →  stores time-series metrics
        │
        ▼
   Grafana  →  dashboards & Explore (PromQL)
```

### Logs path

```
Kubernetes Pods (stdout/stderr)
        │
        ▼
   Promtail (DaemonSet on each node)
        │
        ▼
   Loki  →  indexes and stores logs
        │
        ▼
   Grafana  →  Explore (LogQL)
```

**Key integration points:**

* **Custom metrics** — `backend/src/lib/metrics.js` exposes Prometheus metrics at `/metrics`
* **ServiceMonitor discovery** — `helm/chat-app/templates/servicemonitor-backend.yaml` tells Prometheus which Service/port to scrape
* **Loki centralized logging** — Promtail automatically collects logs from all pods in the cluster; filter by `{namespace="chat-app"}`
* **Grafana visualization** — single UI for metrics (Prometheus) and logs (Loki); datasource URLs configured in `deploy/argocd/monitoring.yaml`

---

## Project Structure

```
cloud-native-chat-platform/
├── frontend/                  # React app + Dockerfile
├── backend/                   # API + Socket.io + /metrics + auth
│   └── src/
│       ├── lib/metrics.js     # prom-client metric definitions
│       ├── middleware/        # HTTP metrics middleware
│       └── routes/metrics.route.js
├── helm/chat-app/             # Helm chart (all app workloads)
│   ├── values.yaml            # image tags, ingress, HPA, PDB, secrets, resources
│   └── templates/             # Deployments, HPA, PDB, NetworkPolicy, ServiceMonitor, etc.
├── deploy/
│   ├── argocd/
│   │   ├── chat-app.yaml      # ArgoCD app — Helm chart
│   │   ├── monitoring.yaml    # Prometheus + Grafana (+ Loki datasource)
│   │   └── loki.yaml          # Loki + Promtail (loki-stack chart)
│   ├── kind/kind-config.yaml  # Kind cluster (ports 80/443)
│   └── secrets/               # kubeseal instructions (cert is gitignored)
├── load.js                    # k6 load test script (HPA validation)
└── .github/workflows/cicd.yml # CI/CD pipeline
```

---

## Environment Configuration

Create `.env` in project root:

```env
MONGODB_URI=mongodb://root:admin@mongo:27017/chatApp?authSource=admin&retryWrites=true&w=majority
JWT_SECRET=your_strong_secret
PORT=5001
NODE_ENV=production
```

---

## Quick Start (Docker Compose)

### Step 1: Clone repository

```bash
git clone https://github.com/rahul6364/cloud-native-chat-platform.git
cd cloud-native-chat-platform
```

### Step 2: Start app

```bash
docker-compose up -d --build
```

### Step 3: Verify

```bash
docker-compose ps
```

Open `http://localhost`.

---

## 🚀 Kubernetes Deployment from Scratch

This guide assumes you are starting with a **new cluster** (specifically [Kind](https://kind.sigs.k8s.io/)) on a Linux/WSL2 system.

### Step 1: Cluster Setup (Kind)

If you haven't created a cluster yet, use the following configuration to ensure port 80 and 443 are mapped to your host.

1. **Use the repo Kind config** at `deploy/kind/kind-config.yaml`.

2. **Spin up the cluster**:

```bash
kind create cluster --config deploy/kind/kind-config.yaml
```

3. **Verify connectivity**:

```bash
kubectl cluster-info
```

### Step 2: Core Infrastructure (Ingress & Secrets)

Before deploying the app, we need the "plumbing" for routing and security.

#### 1. Install Ingress-Nginx (Kind optimized)

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
# Wait for it to be ready
kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=120s
```

#### 2. Install Sealed Secrets Controller (Crucial)

This project uses **Sealed Secrets** to store credentials safely in Git. Without this, your backend won't start.

```bash
helm repo add sealed-secrets https://bitnami-labs.github.io/sealed-secrets
helm install sealed-secrets sealed-secrets/sealed-secrets -n kube-system
```

### 🔐 Re-sealing Secrets for a New Cluster

Since Sealed Secrets are encrypted with a key unique to each cluster, the ciphertext in `helm/chat-app/values.yaml` (`sealedSecret.encryptedData`) will NOT work on a fresh cluster. Follow these steps to generate your own:

1. **Install the `kubeseal` CLI**:

   ```bash
   curl -Lo kubeseal-linux-amd64.tar.gz https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.36.1/kubeseal-0.36.1-linux-amd64.tar.gz
   tar -xvzf kubeseal-linux-amd64.tar.gz kubeseal
   sudo install -m 755 kubeseal /usr/local/bin/kubeseal
   ```

2. **Fetch the Cluster Certificate**:

   ```bash
   kubeseal --fetch-cert --controller-name=sealed-secrets --controller-namespace=kube-system > deploy/secrets/pub-cert.pem
   ```

3. **Generate your Encrypted Manifest**:

   ```bash
   read -p "Cloudinary Cloud Name: " CLOUD_NAME
   read -p "Cloudinary API Key: " API_KEY
   read -p "Cloudinary API Secret: " API_SECRET
   JWT_SECRET=$(python3 -c "import secrets; print(secrets.token_hex(32))")

   kubectl create secret generic backend-secrets \
     --from-literal=cloudinary-cloud-name="$CLOUD_NAME" \
     --from-literal=cloudinary-api-key="$API_KEY" \
     --from-literal=cloudinary-api-secret="$API_SECRET" \
     --from-literal=jwt-secret="$JWT_SECRET" \
     --namespace chat-app \
     --dry-run=client -o json | \
     kubeseal --format yaml --cert deploy/secrets/pub-cert.pem > /tmp/backend-sealed.yaml
   ```

4. **Copy encrypted values into Helm**:
   Open `/tmp/backend-sealed.yaml`, copy the `encryptedData` fields into `helm/chat-app/values.yaml` under `sealedSecret.encryptedData` (keys: `cloudinaryApiKey`, `cloudinaryApiSecret`, `cloudinaryCloudName`, `jwtSecret`), then commit and push.

---

### Step 3: Option A - Helm Deployment

Recommended way using the Helm chart in `helm/chat-app`.

1. **Install/Upgrade chart**:

   ```bash
   helm upgrade --install chat-app ./helm/chat-app --create-namespace --namespace chat-app
   ```

2. **Render manifests (optional validation)**:

   ```bash
   helm template chat-app ./helm/chat-app --namespace chat-app
   ```

3. **Customize values (optional)**:
   Edit `helm/chat-app/values.yaml` for image tags, ingress host, and resource settings, then run the same `helm upgrade --install` command again.

### Step 3b: HPA, PDB, and Network Policies

The chart enables these by default in `helm/chat-app/values.yaml`:

| Feature | Components | Purpose |
|---------|------------|---------|
| **Resource requests/limits** | frontend, backend, mongodb | Stable scheduling and CPU/memory caps |
| **HPA** | frontend, backend | Scale 2–5 pods on CPU (~70% target) |
| **PodDisruptionBudget** | frontend, backend, mongodb | Safer node drains / upgrades |
| **NetworkPolicy** | frontend, backend, mongodb | Restrict traffic to expected paths only |

**Install metrics-server** (required for HPA on Kind):

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl patch deployment metrics-server -n kube-system --type='json' \
  -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'
kubectl rollout status deployment/metrics-server -n kube-system --timeout=120s
```

**Verify after sync:**

```bash
kubectl get hpa,pdb,networkpolicy -n chat-app
kubectl top pods -n chat-app
```

**Disable for local debugging** (in `values.yaml`):

```yaml
frontend:
  autoscaling:
    enabled: false
  replicas: 1
backend:
  autoscaling:
    enabled: false
  replicas: 1
networkPolicy:
  enabled: false
```

> **Note:** Kind's default CNI does not enforce NetworkPolicies. They still apply in production clusters (EKS, GKE, AKS with a policy-aware CNI). For local policy testing, use Kind with [Calico](https://docs.tigera.io/calico/latest/getting-started/kubernetes/kind) or another CNI that supports them.

---

### Step 4: Option B - GitOps Deployment (ArgoCD)

The modern way. ArgoCD will monitor your repository and automatically sync changes.

1. **Install ArgoCD**:

   ```bash
   kubectl create namespace argocd
   kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
   kubectl -n argocd rollout status deployment/argocd-server --timeout=180s
   ```

2. **Access ArgoCD UI**:

   ```bash
   kubectl port-forward svc/argocd-server -n argocd 8081:443
   ```

   Login at `https://localhost:8081` (Username: `admin`).

3. **Get Admin Password**:

   ```bash
   kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo
   ```

4. **Connect the Application**:
   Apply the ArgoCD Application manifests (repo: `cloud-native-chat-platform`, branch: `main`):

   ```bash
   kubectl apply -f deploy/argocd/chat-app.yaml
   kubectl apply -f deploy/argocd/monitoring.yaml
   kubectl apply -f deploy/argocd/loki.yaml
   ```

5. **If the repo is private**, register credentials in ArgoCD once:

   ```bash
   argocd repo add https://github.com/rahul6364/cloud-native-chat-platform.git \
     --username <github-username> --password <github-pat>
   ```

   Or add the repo in the ArgoCD UI under **Settings → Repositories**.

6. **Refresh and sync** in the ArgoCD UI (or CLI):

   ```bash
   argocd app get chat-app
   argocd app sync chat-app
   argocd app sync monitoring-stack
   argocd app sync loki
   ```

*ArgoCD pulls from `https://github.com/rahul6364/cloud-native-chat-platform.git` and deploys the Helm chart at `helm/chat-app`.*

### ArgoCD troubleshooting

| Error | Fix |
|-------|-----|
| `unable to resolve 'helm-migration' to a commit SHA` | Branch was never pushed; use `targetRevision: main` in `deploy/argocd/chat-app.yaml` and re-apply. |
| `repository not accessible` | Add GitHub PAT in ArgoCD if the repo is private. |
| SealedSecret sync failed | Re-seal secrets for your cluster (see [Re-sealing Secrets](#-re-sealing-secrets-for-a-new-cluster)). |
| Socket.io `400 Bad Request` / WebSocket closed | Backend runs multiple replicas; Socket.io sessions are per-pod. Ensure ingress has **cookie affinity** (`nginx.ingress.kubernetes.io/affinity: cookie` in `helm/chat-app/values.yaml`) and sync the app. |

### Socket.io with multiple backend replicas

Socket.io keeps connection state in **process memory**. With HPA (2+ backend pods), polling/WebSocket follow-ups can hit a different pod than the handshake and return `400`.

The Helm chart configures **sticky sessions** on the ingress (cookie affinity) and on the `backend` Service (`sessionAffinity: ClientIP`). After changing values, sync ArgoCD or run `helm upgrade` and hard-refresh the browser.

For production at scale, consider a shared adapter (e.g. `@socket.io/redis-adapter` with Redis) so replicas can share socket state without stickiness.

---

## Load Testing & Autoscaling Validation

HPA behavior was validated using **[k6](https://k6.io/)** load testing against the backend health endpoint.

### Prerequisites

```bash
# Install k6 (Linux/WSL)
sudo gpg -k
sudo gpg --no-default-keyring --keyring /usr/share/keyrings/k6-archive-keyring.gpg \
  --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys C5AD17C747EF1D5A369A0D0D692B4735643FAE3
echo "deb [signed-by=/usr/share/keyrings/k6-archive-keyring.gpg] https://dl.k6.io/deb stable main" | \
  sudo tee /etc/apt/sources.list.d/k6.list
sudo apt-get update && sudo apt-get install k6

# Ensure metrics-server is running (see Step 3b above)
kubectl top pods -n chat-app
```

### Example test configuration

The repo includes `load.js` at the project root:

```javascript
import http from "k6/http";

export const options = {
  vus: 10,        // 10 virtual users
  duration: "30s",
};

export default function () {
  http.get("http://localhost:5001/health");
}
```

### Run the test

In one terminal, port-forward the backend service:

```bash
kubectl port-forward -n chat-app svc/backend 5001:5001
```

In another terminal, watch HPA and pods scaling in real time:

```bash
kubectl get hpa -n chat-app -w
kubectl get pods -n chat-app -w
kubectl top pods -n chat-app
```

Run k6:

```bash
k6 run load.js
```

### Observed HPA behavior

| Observation | Result |
|-------------|--------|
| Initial backend replicas | 2 (HPA `minReplicas: 2`) |
| CPU threshold | 70% average utilization |
| Under load | Backend CPU rose above threshold |
| Autoscaling action | HPA scaled backend from **2 → 3 replicas** |
| After load stopped | Replicas scaled back down after stabilization window |

```bash
# Verify HPA status
kubectl get hpa -n chat-app

# Example output:
# NAME             REFERENCE           TARGETS         MINPODS   MAXPODS   REPLICAS
# backend-hpa      Deployment/backend  85%/70%         2         5         3
# frontend-hpa     Deployment/frontend 45%/70%         2         5         2
```

---

## 🌐 Accessing the Application

Since we use Ingress with host-based routing (`chat-app.com`), common for production setups:

1. **Update Local Hosts File**:
   Add this line to `/etc/hosts` (Linux/Mac) or `C:\Windows\System32\drivers\etc\hosts` (Windows):

   ```text
   127.0.0.1  chat-app.com
   ```

2. **Expose the Ingress Controller locally**:

   ```bash
   kubectl port-forward -n ingress-nginx svc/ingress-nginx-controller 8080:80
   ```

   Reach the app at: `http://chat-app.com:8080`.

3. **Public Access via Ngrok (Optional)**:

   ```bash
   ngrok http 8080 --host-header="chat-app.com"
   ```

---

## 📊 Monitoring & Observability

Full stack: **Prometheus** (metrics), **Loki** (logs), **Promtail** (log collection), **Grafana** (UI). The backend exposes **`/metrics`** via [prom-client](https://github.com/siimon/prom-client).

| Component | ArgoCD manifest | Role |
|-----------|-----------------|------|
| Prometheus + Grafana | `deploy/argocd/monitoring.yaml` | Metrics, dashboards, alerts |
| Loki + Promtail | `deploy/argocd/loki.yaml` | Centralized logs (`loki-stack` chart) |
| App metrics | `helm/chat-app` + `ServiceMonitor` | Scrapes `backend:5001/metrics` |

### Deploy observability (ArgoCD)

```bash
kubectl apply -f deploy/argocd/monitoring.yaml
kubectl apply -f deploy/argocd/loki.yaml
```

Wait until `monitoring-stack` and `loki` are **Synced** / **Healthy**, then:

```bash
kubectl get pods -n monitoring
kubectl get servicemonitor -n chat-app
```

### Application metrics (`/metrics`)

Custom metrics implemented in `backend/src/lib/metrics.js` and exposed at `GET /metrics`:

| Metric | Type | Labels | Description |
|--------|------|--------|-------------|
| `chatapp_http_requests_total` | Counter | `method`, `route`, `status_code` | Total HTTP requests handled by the API |
| `chatapp_http_request_duration_seconds` | Histogram | `method`, `route`, `status_code` | Request latency distribution (buckets: 5 ms – 5 s) |
| `chatapp_socket_connections_active` | Gauge | — | Current number of active Socket.io connections |
| `chatapp_active_users` | Gauge | — | Users with an active socket session (online presence map) |

Additional default Node.js metrics are exported with the `chatapp_` prefix via `prom-client`'s `collectDefaultMetrics`.

**Local check:**

```bash
kubectl port-forward -n chat-app svc/backend 5001:5001
curl -s http://localhost:5001/metrics | grep chatapp_
```

**Grafana → Explore → Prometheus** example queries:

```promql
# Request rate by route
sum(rate(chatapp_http_requests_total[5m])) by (route)

# 95th percentile latency
histogram_quantile(0.95, sum(rate(chatapp_http_request_duration_seconds_bucket[5m])) by (le))

# Real-time online users and socket connections
chatapp_active_users
chatapp_socket_connections_active

# Error rate
sum(rate(chatapp_http_requests_total{status_code=~"5.."}[5m]))
```

### Centralized logs (Loki + Promtail)

Promtail runs as a DaemonSet and automatically ships container logs to Loki. No application code changes required — `console.log` and stderr output are collected.

**Grafana → Explore → Loki** (datasource pre-configured in `monitoring.yaml`):

```logql
# All chat-app logs
{namespace="chat-app"}

# Backend errors only
{namespace="chat-app", pod=~"backend.*"} |= "error"

# Frontend logs
{namespace="chat-app", pod=~"frontend.*"}

# Socket.io connection events
{namespace="chat-app", pod=~"backend.*"} |= "connected"
```

Enable **Live** mode in Explore to tail logs in real time while testing.

### Access Grafana

```bash
kubectl port-forward -n monitoring svc/monitoring-stack-grafana 3000:80
```

- **URL**: http://localhost:3000
- **User**: `admin`
- **Password**: `admin123`

Import dashboard **315** (Kubernetes cluster) or build panels from the PromQL / LogQL queries above.

### Access Prometheus

```bash
kubectl port-forward -n monitoring svc/monitoring-stack-kube-prom-prometheus 9090:9090
```

- **URL**: http://localhost:9090

Search for `chatapp_` in the Prometheus query UI to verify custom metrics are being scraped.

> If service names differ: `kubectl get svc -n monitoring`

---

## Validation Checklist

- [ ] **Cluster Health**: `kubectl get nodes` (Ready)
- [ ] **ArgoCD Apps**: `chat-app`, `monitoring-stack`, `loki` — Synced & Healthy
- [ ] **Namespace**: `kubectl get pods -n chat-app` (All Running)
- [ ] **Ingress**: `kubectl get ingress -n chat-app` (Hostname `chat-app.com` visible)
- [ ] **Browser access** at `http://chat-app.com:8080/`
- [ ] **HPA**: `kubectl get hpa -n chat-app` (targets visible, minReplicas: 2)
- [ ] **Monitoring**: `kubectl get pods -n monitoring` (All Running)
- [ ] **Grafana**: Accessible at `http://localhost:3000` (Loki + Prometheus datasources)
- [ ] **Backend metrics**: `curl localhost:5001/metrics` shows `chatapp_*` metrics; Prometheus targets show `backend` ServiceMonitor UP
- [ ] **Loki logs**: Grafana Explore → `{namespace="chat-app"}` returns backend/frontend lines
- [ ] **Load test**: k6 run causes backend HPA to scale above `minReplicas` under CPU load

---

## Issues Faced and Fixes

### 1) Ingress hostname mismatch

* **Fix:** set host in `helm/chat-app/values.yaml` (`ingress.host`) to `chat-app.com`, add `127.0.0.1 chat-app.com` in hosts file.

### 2) Auth 401 on protected APIs after login

* **Fix:** set `backend.env.nodeEnv: development` in `helm/chat-app/values.yaml` for local Kind HTTP testing (cookies `secure: false`).

### 3) Empty JWT secret causing 500 errors

* **Fix:** regenerate and apply the secret with a non-empty random value.

### 4) MongoDB pods not becoming ready after migration

* **Fix:** delete old Deployment and ClusterIP service before applying StatefulSet and headless service.

### 5) Socket.io 400 / WebSocket closed with multiple backend replicas

* **Problem:** Socket.io session created on one pod; follow-up requests routed to a different pod.
* **Fix:** added ingress cookie affinity and backend Service `sessionAffinity: ClientIP` in the Helm chart.

### 6) Prometheus showed no custom application metrics

* **Problem:** Grafana/Prometheus had no `chatapp_*` series despite `/metrics` working via port-forward.
* **Root cause:** the backend Service lacked metadata labels required by the ServiceMonitor selector (`app: backend`).
* **Fix:** added `metadata.labels.app: backend` to `helm/chat-app/templates/backend-service.yaml` so Prometheus ServiceMonitor discovery could find and scrape the metrics endpoint. Also named the Service port `http` to match the ServiceMonitor `endpoints.port` field.

### 7) Loki datasource health-check warning in Grafana

* **Problem:** Grafana showed a warning on the Loki datasource health check.
* **Root cause:** known Grafana/Loki health-check compatibility issue with the `loki-stack` chart version.
* **Resolution:** Loki log queries work correctly — use **Grafana → Explore → Loki** with `{namespace="chat-app"}`. Logs are visible despite the datasource health-check warning. No action required for local/Kind deployments.

---

## CI/CD Status

This repository has a production-grade GitHub Actions pipeline in `.github/workflows/cicd.yml`.

### Pipeline stages

| Stage | Tool | Purpose |
|-------|------|---------|
| Secret scan | Gitleaks | Prevent credential leaks in Git |
| Lint | ESLint | Frontend code quality |
| Static analysis | CodeQL | Security vulnerability detection |
| Build | Docker Buildx | Multi-stage frontend + backend images |
| Container scan | Trivy | CRITICAL/HIGH CVE detection (SARIF → GitHub Security tab) |
| Push | Docker Hub | SHA tag + `latest` |
| GitOps update | Python script | Bumps `helm/chat-app/values.yaml` image tags |
| Deploy | ArgoCD | Auto-sync rolls out new pods |

See [GitOps Workflow](#gitops-workflow) for the full end-to-end diagram.

---

## Project Achievements

* Migrated raw Kubernetes manifests to a structured **Helm chart** with parameterized values.
* Implemented a **GitOps deployment model** using ArgoCD with automated sync and self-heal.
* Implemented **centralized logging** using Loki and Promtail — logs from all pods searchable in Grafana.
* Implemented **application observability** using Prometheus and Grafana with custom `prom-client` metrics.
* Implemented **autoscaling (HPA)** and validated it through **k6 load testing** (backend scaled 2 → 3 replicas under load).
* Secured secrets using **Bitnami Sealed Secrets** — credentials safe to commit in a public repository.
* Hardened workloads using **Pod Disruption Budgets**, **Network Policies**, and **resource requests/limits**.
* Migrated MongoDB to a **StatefulSet** architecture with persistent storage and stable DNS.
* Built a full **CI/CD pipeline** with Trivy scanning, Docker Hub publishing, and automated Helm tag updates.
* Resolved production issues including Socket.io multi-replica stickiness and Prometheus ServiceMonitor discovery.

---

## Contributing

Contributions are welcome! Please report issues or open pull requests.

## License

This project is licensed under the MIT License.
