# Real-Time Chat Application

A full-stack real-time chat application built with React, Node.js/Express, Socket.io, MongoDB, Docker, and Kubernetes (Kind).

## Table of Contents

* [Introduction](#introduction)
* [Features](#features)
* [Tech Stack](#tech-stack)
* [Current Project Status](#current-project-status)
* [Project Structure](#project-structure)
* [Environment Configuration](#environment-configuration)
* [Quick Start (Docker Compose)](#quick-start-docker-compose)
* [🚀 Kubernetes Deployment from Scratch](#-kubernetes-deployment-from-scratch)
    * [Step 1: Cluster Setup (Kind)](#step-1-cluster-setup-kind)
    * [Step 2: Core Infrastructure (Ingress & Secrets)](#step-2-core-infrastructure-ingress--secrets)
    * [Step 3: Option A - Helm Deployment](#step-3-option-a---helm-deployment)
    * [Step 4: Option B - GitOps Deployment (ArgoCD)](#step-4-option-b---gitops-deployment-argocd)
* [🌐 Accessing the Application](#-accessing-the-application)
* [Validation Checklist](#validation-checklist)
* [Issues Faced and Fixes](#issues-faced-and-fixes)
* [CI/CD Status](#cicd-status)
* [Contributing](#contributing)
* [License](#license)

---

## Introduction

This project provides a scalable and production-style chat application with:
* JWT authentication
* real-time messaging with Socket.io
* MongoDB persistence
* containerized local and Kubernetes deployments

## Features

* Real-time messaging with Socket.io
* JWT-based auth and protected routes
* Profile updates and online user presence
* React + TailwindCSS frontend
* Docker and Kubernetes support

## Tech Stack

* **Backend:** Node.js, Express, Socket.io, MongoDB
* **Frontend:** React, TailwindCSS, Zustand
* **Containerization:** Docker
* **Orchestration:** Kubernetes (Kind + ingress-nginx)
* **Web Server:** Nginx
* **Authentication:** JWT + HTTP-only cookies
* **GitOps / CD:** ArgoCD
* **Packaging:** Helm
* **Tunneling (demo):** Ngrok

## Repository

**GitHub:** [rahul6364/cloud-native-chat-platform](https://github.com/rahul6364/cloud-native-chat-platform)

```bash
git clone https://github.com/rahul6364/cloud-native-chat-platform.git
cd cloud-native-chat-platform
```

## Current Project Status

### Implemented

* Backend, frontend, and MongoDB are containerized and deployable.
* Local deployment with Docker Compose works.
* Kubernetes deployment on Kind works.
* `ingress-nginx` is configured and routing traffic.
* Host-based access is working through `chat-app.com`.
* **MongoDB migrated from Deployment → StatefulSet** with a headless service (`clusterIP: None`) for stable DNS.
* **Backend health endpoint** (`/health`) returns `503` when MongoDB is not connected.
* **Readiness + liveness probes** added to backend and MongoDB.
* **CI/CD pipeline** builds, scans (Trivy), and publishes Docker images.
* **ArgoCD GitOps CD** enabled for automated manifest synchronization.
* **Security Hardening**: Implemented **Bitnami Sealed Secrets** to securely store credentials (JWT, Cloudinary) in the public repository.
* **Payload Support**: Increased request limits to **10MB** (Express + Nginx Ingress) for profile picture uploads.
* **Infrastructure Optimization**: Cleaned up redundant PVCs and fixed ArgoCD health monitoring.
* **Local K8s Auth Fix**: Optimized cookie and CORS settings for plain HTTP access via `chat-app.com:8080`.
* **Helm migration**: Kubernetes manifests moved to `helm/chat-app/`; ArgoCD deploys the Helm chart from `main`.
* **Repository renamed**: Canonical repo is `cloud-native-chat-platform` (ArgoCD `repoURL` updated).
* **Production hardening**: HPA, PodDisruptionBudgets, NetworkPolicies, and resource requests/limits on all workloads (via Helm values).
* **Observability**: Prometheus metrics (`/metrics` + ServiceMonitor), Loki/Promtail centralized logs, Grafana dashboards.

---

## Project Structure

* `frontend/` - React app + `frontend/Dockerfile`
* `backend/` - API + socket server + auth
* `helm/chat-app/` - Helm chart (app workloads)
  * `values.yaml` - image tags, ingress, resources, HPA, PDB, network policies, secrets
  * `templates/` - deployments, HPA, PDB, NetworkPolicy, services, ingress, etc.
* `deploy/` - cluster bootstrap & GitOps
  * `argocd/chat-app.yaml` - ArgoCD app for the chat Helm chart
  * `argocd/monitoring.yaml` - Prometheus + Grafana
  * `argocd/loki.yaml` - Loki + Promtail logging stack
  * `kind/kind-config.yaml` - Kind cluster config (ports 80/443)
  * `secrets/` - kubeseal instructions (cluster cert is gitignored)

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
# Add Helm repo and install
helm repo add sealed-secrets https://bitnami-labs.github.io/sealed-secrets
helm install sealed-secrets sealed-secrets/sealed-secrets -n kube-system
```

### 🔐 Re-sealing Secrets for a New Cluster

Since Sealed Secrets are encrypted with a key unique to each cluster, the ciphertext in `helm/chat-app/values.yaml` (`sealedSecret.encryptedData`) will NOT work on a fresh cluster. Follow these steps to generate your own:

1. **Install the `kubeseal` CLI**:
   ```bash
   # Download and install the latest version for Linux/AMD64
   curl -Lo kubeseal-linux-amd64.tar.gz https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.36.1/kubeseal-0.36.1-linux-amd64.tar.gz
   tar -xvzf kubeseal-linux-amd64.tar.gz kubeseal
   sudo install -m 755 kubeseal /usr/local/bin/kubeseal
   ```

2. **Fetch the Cluster Certificate**:
   ```bash
   kubeseal --fetch-cert --controller-name=sealed-secrets --controller-namespace=kube-system > deploy/secrets/pub-cert.pem
   ```

3. **Generate your Encrypted Manifest**:
   Run this script to securely encrypt your Cloudinary and JWT credentials:
   ```bash
   # Enter your actual values when prompted
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

> **Note:** Kind’s default CNI does not enforce NetworkPolicies. They still apply in production clusters (EKS, GKE, AKS with a policy-aware CNI). For local policy testing, use Kind with [Calico](https://docs.tigera.io/calico/latest/getting-started/kubernetes/kind) or another CNI that supports them.

---

### Step 4: Option B - GitOps Deployment (ArgoCD)

The modern way. ArgoCD will monitor your repository and automatically sync changes.

1. **Install ArgoCD**:
   ```bash
   kubectl create namespace argocd
   kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
   # Wait for rollout
   kubectl -n argocd rollout status deployment/argocd-server --timeout=180s
   ```

2. **Access ArgoCD UI**:
   ```bash
   # Port forward to localhost:8081
   kubectl port-forward svc/argocd-server -n argocd 8081:443
   ```
   *Login at `https://localhost:8081` (Username: `admin`)*.

3. **Get Admin Password**:
   ```bash
   kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo
   ```

4. **Connect the Application**:
   Apply the ArgoCD Application manifest (repo: `cloud-native-chat-platform`, branch: `main`, path: `helm/chat-app`):
   ```bash
   kubectl apply -f deploy/argocd/chat-app.yaml
   kubectl apply -f deploy/argocd/monitoring.yaml
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
   ```

*ArgoCD pulls from `https://github.com/rahul6364/cloud-native-chat-platform.git` and deploys the Helm chart at `helm/chat-app`.*

### ArgoCD troubleshooting

| Error | Fix |
|-------|-----|
| `unable to resolve 'helm-migration' to a commit SHA` | Branch was never pushed; use `targetRevision: main` in `deploy/argocd/chat-app.yaml` and re-apply. |
| `repository not accessible` | Add GitHub PAT in ArgoCD if the repo is private. |
| SealedSecret sync failed | Re-seal secrets for your cluster (see [Re-sealing Secrets](#-re-sealing-secrets-for-a-new-cluster)). |

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
   If you want to test on mobile or share it publicly:
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

Rebuild and deploy the **backend** image after pulling this branch (metrics code is in the Node app):

```bash
# After CI pushes a new image tag, ArgoCD syncs chat-app — or bump tag in helm/chat-app/values.yaml
```

### Application metrics (`/metrics`)

Installed in `backend/` with `prom-client`. Endpoints:

| Metric | Type | Description |
|--------|------|-------------|
| `chatapp_http_requests_total` | Counter | HTTP requests by method, route, status |
| `chatapp_http_request_duration_seconds` | Histogram | Request latency |
| `chatapp_socket_connections_active` | Gauge | Active Socket.io connections |
| `chatapp_active_users` | Gauge | Users online (socket map) |

Local check:

```bash
curl -s http://localhost:5001/metrics | head -20
```

**Grafana → Explore → Prometheus** example queries:

```promql
sum(rate(chatapp_http_requests_total[5m])) by (route)
histogram_quantile(0.95, sum(rate(chatapp_http_request_duration_seconds_bucket[5m])) by (le))
chatapp_active_users
chatapp_socket_connections_active
```

### Centralized logs (Loki + Promtail)

**Grafana → Explore → Loki** (datasource pre-configured in `monitoring.yaml`):

```logql
{namespace="chat-app"} |= "error"
{namespace="chat-app", pod=~"backend.*"} | json
{namespace="chat-app", pod=~"frontend.*"}
```

### Access Grafana

```bash
kubectl port-forward -n monitoring svc/monitoring-stack-grafana 3000:80
```

- **URL**: http://localhost:3000
- **User**: `admin`
- **Password**: `admin123`

Import dashboard **315** (Kubernetes cluster) or build panels from the PromQL / LogQL above.

### Access Prometheus

```bash
kubectl port-forward -n monitoring svc/monitoring-stack-kube-prom-prometheus 9090:9090
```

- **URL**: http://localhost:9090

> If service names differ: `kubectl get svc -n monitoring`

---

## Validation Checklist

- [ ] **Cluster Health**: `kubectl get nodes` (Ready)
- [ ] **ArgoCD App**: Status `Synced` & `Healthy` in UI.
- [ ] **Namespace**: `kubectl get pods -n chat-app` (All Running)
- [ ] **Ingress**: `kubectl get ingress -n chat-app` (Hostname chat-app.com visible)
- [ ] **Browser access** at `http://chat-app.com:8080/`.
- [ ] **Monitoring**: `kubectl get pods -n monitoring` (All Running)
- [ ] **Grafana**: Accessible at `http://localhost:3000` (Loki + Prometheus datasources).
- [ ] **Backend metrics**: `kubectl port-forward -n chat-app svc/backend 5001:5001` then `curl localhost:5001/metrics`.
- [ ] **Loki logs**: Grafana Explore → `{namespace="chat-app"}` returns backend/frontend lines.

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

---

## CI/CD Status

This repository has a production-grade GitHub Actions pipeline in `.github/workflows/cicd.yml`.

### End-to-end GitOps flow

```
Code push to main
  → GitHub Actions CI
  → Build + scan + push Docker images (SHA tag)
  → Update helm/chat-app/values.yaml with new SHA tag
  → Commit + push Helm values change to main
  → ArgoCD detects diff → syncs to Kind cluster
  → Pods roll out with new image
```

---

## Contributing

Contributions are welcome! Please report issues or open pull requests.

## License

This project is licensed under the MIT License.
