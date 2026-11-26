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
* [GitOps & CI/CD Workflow](#gitops--cicd-workflow)
* [Observability Architecture](#observability-architecture)
* [Project Structure](#project-structure)
* [Environment Configuration](#environment-configuration)
* [Quick Start (Docker Compose)](#quick-start-docker-compose)
* [🚀 Infrastructure Setup (AWS EC2 + Kind)](#-infrastructure-setup-aws-ec2--kind)
    * [EC2 requirements](#ec2-requirements)
    * [Ubuntu prerequisites](#ubuntu-prerequisites)
    * [Create the Kind cluster](#create-the-kind-cluster)
    * [Step 2: Core Infrastructure (Ingress & Secrets)](#step-2-core-infrastructure-ingress--secrets)
    * [Step 3: Option A - Helm Deployment](#step-3-option-a---helm-deployment)
    * [Step 3b: HPA, PDB, and Network Policies](#step-3b-hpa-pdb-and-network-policies)
    * [Step 4: Option B - GitOps Deployment (ArgoCD)](#step-4-option-b---gitops-deployment-argocd)
    * [Routine updates](#routine-updates)
    * [EC2 Restart & IP-Change Recovery](#ec2-restart--ip-change-recovery)
* [Load Testing & Autoscaling Validation](#load-testing--autoscaling-validation)
* [🌐 Accessing the Services (ChatApp / Grafana / ArgoCD)](#-accessing-the-services-chatapp--grafana--argocd)
* [📊 Monitoring & Observability](#-monitoring--observability)
* [Validation Checklist](#validation-checklist)
* [Troubleshooting](#troubleshooting)
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
| **GitOps** | ArgoCD watches the deployed branch and auto-syncs Helm values to the cluster |
| **Metrics** | Prometheus scrapes custom app metrics from `GET /metrics` via ServiceMonitor |
| **Dashboards** | Grafana with Prometheus and Loki datasources pre-configured |
| **Logging** | Loki + Grafana Alloy centralized log aggregation from all pods |
| **Autoscaling** | Horizontal Pod Autoscaler (HPA) on frontend and backend (2–5 replicas, 70% CPU target) — disabled on the EC2 profile (`values-ec2.yaml`, single 2 vCPU node) |
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
| **Observability** | Prometheus, Grafana, Loki, Grafana Alloy |
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
| **Helm migration** | Raw K8s manifests migrated to `helm/chat-app/`; ArgoCD deploys from the `restore-kind-gitops` branch |
| **GitOps** | ArgoCD auto-sync enabled for chat-app, monitoring, and Loki stacks |
| **MongoDB** | Migrated from Deployment → **StatefulSet** with headless service and PVC |
| **Health checks** | Backend `/health` returns `503` when MongoDB is disconnected; readiness/liveness probes on all workloads |
| **Security** | Bitnami Sealed Secrets for JWT and Cloudinary credentials in Git |
| **Production hardening** | HPA, PDBs, NetworkPolicies, resource requests/limits (via Helm values) |
| **HPA validation** | **Validated with k6** — backend scaled automatically from **2 → 3 replicas** when CPU exceeded the 70% threshold |
| **Prometheus metrics** | Custom application metrics successfully scraped via ServiceMonitor |
| **Grafana** | Dashboards and Explore views operational (Prometheus + Loki datasources) |
| **Loki + Grafana Alloy** | Centralized application logs collected and visible in Grafana Explore |
| **Observability stack** | End-to-end metrics + logs pipeline verified |
| **CI/CD** | GitHub Actions builds, scans (Trivy), pushes images, and updates Helm image tags |
| **Socket.io multi-replica** | Ingress cookie affinity + backend session affinity for sticky Socket.io sessions |
| **Payload support** | 10 MB request limits (Express + Nginx Ingress) for profile picture uploads |

---

## Production Architecture

Runtime topology. CI/CD is shown separately in the
[CI/CD Pipeline](#cicd-pipeline-github-actions--docker-hub--argocd) diagram.

```mermaid
graph LR
    classDef ext fill:#2d3748,stroke:#4a5568,stroke-width:2px,color:#fff;
    classDef ing fill:#2b6cb0,stroke:#63b3ed,stroke-width:2px,color:#fff;
    classDef app fill:#2f855a,stroke:#68d391,stroke-width:2px,color:#fff;
    classDef storage fill:#c05621,stroke:#fbd38d,stroke-width:2px,color:#fff;
    classDef monitor fill:#553c9a,stroke:#b794f4,stroke-width:2px,color:#fff;
    classDef gitops fill:#744210,stroke:#ecc94b,stroke-width:2px,color:#fff;

    User((User Browser)):::ext -->|"chat.PUBLIC_IP.nip.io :80"| Ingress

    subgraph EC2 ["AWS EC2 (Ubuntu) — Docker"]
        subgraph Kind ["Kind Kubernetes Cluster"]
            Ingress["NGINX Ingress Controller<br/>(host ports 80/443)"]:::ing
            subgraph App ["namespace: chat-app"]
                FE["Frontend Pods<br/>React + Nginx"]:::app
                BE["Backend Pods<br/>Node.js + Express + Socket.IO"]:::app
                Redis[("Redis<br/>Socket.IO pub/sub")]:::storage
                DB[("MongoDB StatefulSet<br/>PVC")]:::storage
            end
            subgraph Ops ["namespaces: monitoring / argocd"]
                Argo["ArgoCD<br/>(GitOps)"]:::gitops
                Prom[("Prometheus")]:::monitor
                Graf["Grafana"]:::monitor
                Loki[("Loki")]:::monitor
                Alloy["Grafana Alloy<br/>(DaemonSet)"]:::monitor
            end
        end
    end

    Ingress -->|"/"| FE
    Ingress -->|"/api, /socket.io"| BE
    Ingress -->|"/grafana host"| Graf
    Ingress -->|"/argocd host"| Argo
    BE --> DB
    BE -.-> Redis
    BE -->|"/metrics"| Prom
    Alloy -->|"pod logs"| Loki
    Prom --> Graf
    Loki --> Graf
    Argo -.->|"sync from Git"| App
    Argo -.->|"sync from Git"| Ops
```

```
┌─────────────────────────── AWS EC2 instance — Ubuntu ────────────────────────────┐
│                                                                                  │
│  Docker ─▶ runs the Kind node container that hosts the whole cluster below       │
  ┌───────────── Docker container — Kind node: Kubernetes cluster ─────────────┐
  │                                                                            │
  │  Users ─▶ :80/:443 ─▶ NGINX Ingress ─┬─▶ Frontend (React + Nginx)          │
  │  chat.PUBLIC_IP.nip.io                 └─▶ Backend (Node.js, Express,      │
  │                                                  Socket.IO)                │
  │                                                                            │
  │  Backend ─▶ MongoDB (StatefulSet + PVC)     Backend ◀▶ Redis (Socket.IO    │
  │                                                 pub/sub adapter)           │
  │                                                                            │
  │  namespace monitoring                                                      │
  │    Prometheus ◀─ /metrics ─ Backend    Alloy (DaemonSet) ─ pod logs ─▶ Loki│
  │    Grafana ◀─ Prometheus + Loki                                            │
  │                                                                            │
  │  namespace argocd                                                          │
  │    ArgoCD ◀─ watches GitHub ─ syncs every workload in this box             │
  └────────────────────────────────────────────────────────────────────────────┘
│                                                                                  │
│  GitHub (source of truth) ◀─ push ─ GitHub Actions: build, scan, publish images  │
│  (see "CI/CD Pipeline" diagram above)                                            │
└──────────────────────────────────────────────────────────────────────────────────┘
```

| Component | Role |
|-----------|------|
| **Frontend Deployment** | Serves React SPA via Nginx; proxies `/api` and `/socket.io` internally when accessed via service |
| **Backend Deployment** | REST API, Socket.io server, JWT auth, Prometheus `/metrics` endpoint |
| **MongoDB StatefulSet** | Persistent chat data with stable network identity and a PVC |
| **Kind** | Single-node Kubernetes cluster running inside Docker on the EC2 host |
| **Ingress NGINX** | Host-based routing on nip.io hostnames, WebSocket support, cookie affinity for Socket.io |
| **ArgoCD** | Watches the Git branch; auto-syncs the Helm chart and observability stacks |
| **Prometheus** | Scrapes Kubernetes and custom application metrics |
| **Grafana** | Visualization — dashboards, Explore, alerting |
| **Loki** | Centralized log aggregation and indexing |
| **Grafana Alloy** | DaemonSet that discovers pod logs and ships them to Loki |

---

## GitOps Workflow

Every push to the deployed branch (`restore-kind-gitops` on EC2; `main` for dev) triggers a fully automated delivery pipeline:

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
  └── helm/chat-app/values-ec2.yaml image tags bumped to new SHA
        │
        ▼
Git commit + push to main  [skip ci]
        │
        ▼
ArgoCD detects diff
  ├── chat-app      → syncs Helm chart
  ├── monitoring-stack → Prometheus + Grafana
  ├── loki          → Loki (log storage, single binary)
  └── alloy         → Grafana Alloy (log collector DaemonSet)
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
| `loki` | `deploy/argocd/loki.yaml` | Loki (single binary, log storage) |
| `alloy` | `deploy/argocd/alloy.yaml` | Grafana Alloy (log collector DaemonSet) |

---

## CI/CD Pipeline (GitHub Actions → Docker Hub → ArgoCD)

```mermaid
graph LR
    classDef vcs fill:#744210,stroke:#ecc94b,stroke-width:2px,color:#fff;
    classDef ci fill:#2b6cb0,stroke:#63b3ed,stroke-width:2px,color:#fff;
    classDef reg fill:#c05621,stroke:#fbd38d,stroke-width:2px,color:#fff;
    classDef cd fill:#744210,stroke:#ecc94b,stroke-width:2px,color:#fff;

    Dev[Developer Push]:::vcs --> GH[GitHub Actions]:::ci
    GH --> Scan[Gitleaks + CodeQL + Trivy]:::ci
    Scan --> Build[Build Backend + Frontend Images]:::ci
    Build --> DH[(Docker Hub<br/>tag: short-SHA + latest)]:::reg
    Dev -->|bump image tag in<br/>helm/chat-app/values-ec2.yaml| Git[(Git: restore-kind-gitops)]:::vcs
    Git --> Argo[ArgoCD auto-sync]:::cd
    Argo --> K8s[(Kind Cluster on EC2)]:::cd
    DH -.->|image pull| K8s
```

The pipeline builds and scans images on every push to the deployed branch (code changes only —
`deploy/**` and `helm/**` changes skip the build). Deployments are **GitOps**: updating the image
`tag` in `helm/chat-app/values-ec2.yaml` and pushing is what triggers ArgoCD to roll out the new
version; the workflow itself never touches the cluster.

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
Kubernetes Pods (stdout/stderr → /var/log/pods on the node)
        │
        ▼
   Grafana Alloy (DaemonSet on each node)
   discovery.kubernetes → discovery.relabel → local.file_match → loki.source.file
        │
        ▼
   Loki  →  indexes and stores logs
        │  (labels: namespace, pod, container, app, node, stream)
        ▼
   Grafana  →  Explore (LogQL)
```

**Key integration points:**

* **Custom metrics** — `backend/src/lib/metrics.js` exposes Prometheus metrics at `/metrics`
* **ServiceMonitor discovery** — `helm/chat-app/templates/servicemonitor-backend.yaml` tells Prometheus which Service/port to scrape
* **Loki centralized logging** — Grafana Alloy automatically collects logs from all pods in the cluster; filter by `{namespace="chat-app"}`
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
│   ├── argocd/                # ArgoCD Applications (bootstrap with kubectl apply)
│   │   ├── chat-app.yaml      # ChatApp — Helm chart with values-ec2.yaml
│   │   ├── monitoring.yaml    # Prometheus + Grafana (+ Loki datasource)
│   │   ├── loki.yaml          # Loki single binary (log storage)
│   │   ├── alloy.yaml         # Grafana Alloy (log collector DaemonSet)
│   │   └── grafana-secret.yaml# SealedSecret for Grafana admin credentials
│   ├── ingress/               # Public ingresses (nip.io hostnames)
│   │   ├── grafana-ingress.yaml
│   │   └── argocd-ingress.yaml
│   ├── monitoring/dashboards/ # Grafana dashboard ConfigMaps (grafana_dashboard: "1")
│   ├── kind/kind-config.yaml  # Kind cluster (ports 80/443)
│   └── secrets/               # kubeseal instructions (cert is gitignored)
├── helm/chat-app/             # Application Helm chart (values-ec2.yaml = live values)
├── scripts/
│   └── update-ec2-endpoints.sh # EC2 IP-change endpoint recovery (idempotent)
├── backend/  frontend/        # Application source (CI builds images)
├── load.js                    # k6 load test script (HPA validation)
├── OBSERVABILITY_PROGRESS.md  # Observability implementation handoff log
├── PROJECT_UPGRADE_PROGRESS.md# Upgrade implementation handoff log
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

## 🚀 Infrastructure Setup (AWS EC2 + Kind)

The deployment runs on a single **AWS EC2 Ubuntu** instance hosting a [Kind](https://kind.sigs.k8s.io/) cluster, with **ArgoCD** applying everything from Git. This section is the **one-time installation** from a fresh EC2 instance. For a purely local setup, see [Quick Start (Docker Compose)](#quick-start-docker-compose).

### EC2 requirements

| Requirement | Value |
|---|---|
| OS | Ubuntu 22.04 LTS |
| Instance size | 2 vCPU / 8 GB RAM recommended (e.g. t3.large) — the full stack incl. monitoring fits comfortably; 2 vCPU / 4 GB works but is tight |
| Disk | 30 GB |
| Security group | Inbound TCP **22** (SSH), **80 + 443** (Kind maps these into the ingress controller) |
| Public IPv4 | Auto-assigned by AWS — **changes when the instance is stopped/started** (see [EC2 Restart & IP-Change Recovery](#ec2-restart--ip-change-recovery)) |

### Ubuntu prerequisites

Install Docker, kubectl, Kind and Helm. Versions this deployment was validated with: Docker 29.x, Kind v0.30, kubectl v1.33, Helm v3.22.

```bash
# Docker (engine + CLI; the Kind node runs inside Docker)
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker $USER && newgrp docker

# kubectl
curl -LO "https://dl.k8s.io/release/v1.33.13/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Kind
[ $(uname -m) = x86_64 ] && curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.30.0/kind-linux-amd64
sudo install -o root -g root -m 0755 kind /usr/local/bin/kind

# Helm 3
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

### Create the Kind cluster

The repo Kind config maps host ports **80/443** into the cluster so NGINX Ingress serves traffic directly on the EC2 public IP — no load balancer needed:

```bash
kind create cluster --config deploy/kind/kind-config.yaml
kubectl cluster-info
kubectl get nodes
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

4. **Connect the Applications**:
   Apply the ArgoCD Application manifests. The live deployment tracks the `restore-kind-gitops`
   branch and renders the Helm chart with `helm/chat-app/values-ec2.yaml` (EC2-specific ingress
   host, image tags, autoscaling-off):

   ```bash
   kubectl apply -f deploy/argocd/chat-app.yaml
   kubectl apply -f deploy/argocd/monitoring.yaml
   kubectl apply -f deploy/argocd/loki.yaml
   kubectl apply -f deploy/argocd/alloy.yaml
   kubectl apply -f deploy/argocd/grafana-secret.yaml
   ```

5. **Apply the public ingresses** (ChatApp's ingress comes from the Helm chart; Grafana and
   ArgoCD ingresses are plain manifests — hostnames must match the current EC2 IP, which
   `scripts/update-ec2-endpoints.sh` sets for you):

   ```bash
   kubectl apply -f deploy/ingress/grafana-ingress.yaml
   kubectl apply -f deploy/ingress/argocd-ingress.yaml
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
   argocd app sync alloy
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

### Routine updates

| Change | What to do |
|---|---|
| **New app version** | CI builds images tagged with the commit SHA on every push. Update `backend.tag` / `frontend.tag` in `helm/chat-app/values-ec2.yaml`, commit + push → ArgoCD rolls out automatically. |
| **Helm values change** (resources, replicas, ingress) | Edit `helm/chat-app/values-ec2.yaml`, commit + push → ArgoCD auto-sync (self-heal keeps the cluster in sync with Git). |
| **Monitoring stack** (dashboards, datasources, retention) | Edit the relevant `deploy/argocd/*.yaml` or `deploy/monitoring/dashboards/` manifests, commit + push. For chart apps with inline values (`loki`, `alloy`, `monitoring-stack`), also `kubectl apply -f deploy/argocd/<app>.yaml` to update the Application spec immediately. |
| **Emergency manual change** | Possible but will be reverted by ArgoCD self-heal unless the matching Git change is committed. |

### EC2 Restart & IP-Change Recovery

The EC2 public IP is **not stable** — it changes when the instance is stopped and started again.
All public hostnames are `<subdomain>.<PUBLIC_IP>.nip.io` wildcards, so after a restart the
ingress hostnames must be updated to the new IP. Recovery flow:

```
EC2 restarted  →  new public IP detected (curl -s https://checkip.amazonaws.com)
      →  scripts/update-ec2-endpoints.sh updates the 3 hostname sources
      →  ingress resources re-applied / ArgoCD syncs
      →  ChatApp / Grafana / ArgoCD verified
```

```bash
bash scripts/update-ec2-endpoints.sh          # update files + apply live, print URLs
bash scripts/update-ec2-endpoints.sh --push   # also commit + push so ArgoCD converges (chat-app ingress is GitOps-managed)
```

What the script covers vs. what needs GitHub:

- **Local only (no push needed):** Grafana and ArgoCD ingress hostnames (their manifests are not ArgoCD-managed), and the immediate live patch of the ChatApp ingress.
- **Requires commit + push:** `helm/chat-app/values-ec2.yaml` (ChatApp ingress host) — ArgoCD's self-heal pulls this from GitHub, so without a push it will revert the live change to the old hostname.
- `deploy/kind/kind-config.yaml` (port maps) survives a restart because the Kind **cluster must be recreated** after an EC2 restart (Kind clusters are not persistent). If that happens, re-run the one-time setup from [Step 2](#step-2-core-infrastructure-ingress--secrets) onward, then the script above. MongoDB data survives via the host-bound PVC only if the cluster is recreated with the same `local-path-provisioner` storage layout — otherwise re-seal secrets and accept data loss (this is a demo environment; for durability use a real cluster or an Elastic IP + stable storage).

> **Elastic IP alternative:** associating an AWS Elastic IP removes the whole problem (IP stays across stop/start). AWS charges ~$0.005/hour for *any* in-use public IPv4 address (your auto-assigned IP already accrues this); an Elastic IP attached to a running instance costs the same, so it is roughly cost-neutral — but it is a manual AWS change and is intentionally not part of the automation.

---

## Load Testing & Autoscaling Validation

HPA behavior was validated using **[k6](https://k6.io/)** load testing against the backend health endpoint.

> **Optional / local only.** This validation was done on a local Kind cluster with HPA enabled.
> The EC2 deployment runs with autoscaling disabled (single 2 vCPU node — see `values-ec2.yaml`),
> so the commands below apply only if you re-enable HPA.

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

## 🌐 Accessing the Services (ChatApp / Grafana / ArgoCD)

All services are exposed through the NGINX ingress controller using **nip.io** wildcards — a free
service that resolves `<anything>.<PUBLIC_IP>.nip.io` to `<PUBLIC_IP>`. Because the hostnames are
derived from the EC2 public IP, no hosts-file edits, DNS setup or TLS certificates are required.
Kind maps host ports 80/443 into the ingress controller, so the hostnames work from anywhere
that can reach the EC2 instance.

Get the current IP with `curl -s https://checkip.amazonaws.com`, then:

| Service | URL (HTTP) | Namespace / resource |
|---|---|---|
| **ChatApp** | `http://chat.<PUBLIC_IP>.nip.io` | `chat-app/chat-app` ingress (Helm-managed) |
| **Grafana** | `http://grafana.<PUBLIC_IP>.nip.io` | `monitoring/grafana-ingress` |
| **ArgoCD** | `http://<PUBLIC_IP>.nip.io` | `argocd/argocd-ingress` |

For the current example IP this is:

```text
http://chat.54.166.64.251.nip.io
http://grafana.54.166.64.251.nip.io
http://54.166.64.251.nip.io            # ArgoCD
```

Credentials:

- **ChatApp** — register a user in the UI (JWT auth).
- **Grafana** — credentials from sealed secret `grafana-admin-credentials`:
  ```bash
  kubectl -n monitoring get secret grafana-admin-credentials \
    -o jsonpath='{.data.admin-user}'     | base64 -d; echo
  kubectl -n monitoring get secret grafana-admin-credentials \
    -o jsonpath='{.data.admin-password}' | base64 -d; echo
  ```
- **ArgoCD** — `admin` + `kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d` (delete the initial secret after first login).

If the URLs stop resolving after an EC2 stop/start, the public IP changed — run
[EC2 Restart & IP-Change Recovery](#ec2-restart--ip-change-recovery).

**Optional troubleshooting access** (when ingress is broken): port-forwarding is still available as
a fallback, e.g. `kubectl port-forward -n monitoring svc/monitoring-stack-grafana 3000:80`.
It is not the primary access method on EC2.

---

## 📊 Monitoring & Observability

Full stack: **Prometheus** (metrics), **Loki** (logs), **Grafana Alloy** (log collection), **Grafana** (UI). The backend exposes **`/metrics`** via [prom-client](https://github.com/siimon/prom-client).

| Component | ArgoCD manifest | Role |
|-----------|-----------------|------|
| Prometheus + Grafana | `deploy/argocd/monitoring.yaml` | Metrics, dashboards, alerts |
| Loki | `deploy/argocd/loki.yaml` | Centralized log storage (single binary, 7-day retention) |
| Grafana Alloy | `deploy/argocd/alloy.yaml` | Log collection DaemonSet — ships pod logs to Loki |
| App metrics | `helm/chat-app` + `ServiceMonitor` | Scrapes `backend:5001/metrics` |

### Deploy observability (ArgoCD)

```bash
kubectl apply -f deploy/argocd/monitoring.yaml
kubectl apply -f deploy/argocd/loki.yaml
kubectl apply -f deploy/argocd/alloy.yaml
```

Wait until `monitoring-stack`, `loki` and `alloy` are **Synced** / **Healthy**, then:

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

### Centralized logs (Loki + Grafana Alloy)

Grafana Alloy runs as a DaemonSet on every node, discovers pods through the Kubernetes API, tails
their log files under `/var/log/pods`, and ships every line to Loki with Kubernetes metadata labels
(`namespace`, `pod`, `container`, `app`, `node`, `stream`). No application code changes are
required — `console.log` and stderr output are collected, including from pods that are not Ready.
Read positions are persisted on the node (`/var/lib/alloy`), so container restarts never re-ingest
or duplicate logs.

**Grafana → Explore → Loki** (datasource pre-configured in `monitoring.yaml`). All queries below
are validated against live data:

```logql
# All backend logs
{namespace="chat-app", app="backend"}

# Backend errors — the app logs plain text, so stream is the reliable signal
{namespace="chat-app", app="backend", stream="stderr"}

# All chat-app logs, and log volume per app
{namespace="chat-app"}
sum by (app) (count_over_time({namespace="chat-app"}[5m]))

# Frontend logs (nginx access logs)
{namespace="chat-app", app="frontend"}

# MongoDB logs (JSON lines — parse fields with | json)
{namespace="chat-app", app="mongodb"} | json

# Redis logs (Redis only logs at startup — widen the time range if empty)
{namespace="chat-app", app="redis"}

# Ingress-nginx access logs
{namespace="ingress-nginx", container="controller"}

# Socket.io connection events
{namespace="chat-app", app="backend"} |= "connected"

# By pod pattern — survives pod restarts (pod names change, app/container labels don't)
{pod=~"backend-.*"}
```

Enable **Live** mode in Explore to tail logs in real time while testing.

### Access Grafana

**Via ingress (EC2):** http://grafana.54.166.64.251.nip.io

**Or port-forward locally:**

```bash
kubectl port-forward -n monitoring svc/monitoring-stack-grafana 3000:80
```

- **URL**: http://localhost:3000
- **Credentials**: from sealed secret `grafana-admin-credentials` (re-seal, don't commit plaintext):
  ```bash
  kubectl -n monitoring get secret grafana-admin-credentials \
    -o jsonpath='{.data.admin-user}'     | base64 -d; echo
  kubectl -n monitoring get secret grafana-admin-credentials \
    -o jsonpath='{.data.admin-password}' | base64 -d; echo
  ```

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
- [ ] **ArgoCD Apps**: `chat-app`, `monitoring-stack`, `loki`, `alloy` — Synced & Healthy
- [ ] **Namespace**: `kubectl get pods -n chat-app` (All Running)
- [ ] **Ingress**: `kubectl get ingress -A` (hosts are `<name>.<PUBLIC_IP>.nip.io`)
- [ ] **Browser access** at `http://chat.<PUBLIC_IP>.nip.io`
- [ ] **HPA**: `kubectl get hpa -n chat-app` (targets visible, minReplicas: 2)
- [ ] **Monitoring**: `kubectl get pods -n monitoring` (All Running)
- [ ] **Grafana**: Accessible at `http://grafana.<PUBLIC_IP>.nip.io` (Loki + Prometheus datasources)
- [ ] **Backend metrics**: `curl localhost:5001/metrics` shows `chatapp_*` metrics; Prometheus targets show `backend` ServiceMonitor UP
- [ ] **Loki logs**: Grafana Explore → `{namespace="chat-app"}` returns backend/frontend lines
- [ ] **Log collection**: `kubectl get pods -n monitoring -l app.kubernetes.io/name=alloy` Running; new pods' logs appear in Loki automatically
- [ ] **Load test**: k6 run causes backend HPA to scale above `minReplicas` under CPU load

---

## Troubleshooting

Runbook items for the live EC2 + Kind deployment. "Issues Faced and Fixes" at the bottom of this
section documents problems hit during development and how they were solved.

### EC2 public IP changed (hostnames stopped working)

```bash
NEW_IP=$(curl -s https://checkip.amazonaws.com) && echo "new IP: $NEW_IP"
bash scripts/update-ec2-endpoints.sh            # updates files + applies ingresses, prints URLs
# ChatApp's ingress is GitOps-managed — to stop ArgoCD reverting it, commit + push:
bash scripts/update-ec2-endpoints.sh --push
```

### Pods not starting / CrashLoopBackOff / ImagePullBackOff

```bash
kubectl get pods -A | grep -v Running           # find offenders
kubectl describe pod <pod> -n <ns>              # see events (scheduling, probes, image)
kubectl logs <pod> -n <ns> --previous           # logs of the crashed container
kubectl get events -A --sort-by=.lastTimestamp | tail -20
```

- `ImagePullBackOff` → image tag doesn't exist in Docker Hub (CI not run / typo in `values-ec2.yaml`). Check `https://hub.docker.com/u/rahul6364` or run the CI publish job.
- `CrashLoopBackOff` → usually missing/invalid secrets (see re-sealing section) or app errors in `--previous` logs.
- `Insufficient cpu` in events → node is at its CPU request budget (2 vCPU); scale down non-essential workloads or lower requests.

### ArgoCD OutOfSync / unhealthy

```bash
kubectl -n argocd get applications              # expected: all Synced + Healthy
argocd app diff chat-app                        # or: kubectl -n argocd describe app chat-app
```

- OutOfSync right after a manual `kubectl` change → expected (self-heal will revert it; make the change in Git instead).
- Stale sync after editing an Application manifest → `kubectl -n argocd annotate application <app> argocd.argoproj.io/refresh=hard --overwrite`.
- Progressing forever → check pod status in the target namespace (usually a stuck rollout behind the scenes).

### Ingress 502 / 503

```bash
kubectl get ingress -A                          # confirm hosts + endpoints
kubectl -n chat-app get endpoints backend frontend   # must have pod IPs; empty = selector/label problem
kubectl -n chat-app logs deploy/backend --tail=20
```

502 usually means the backend pods are restarting (probe failures / secrets) or the service
selector doesn't match the pod labels.

### Grafana datasource failures

```bash
kubectl -n monitoring get pods                  # grafana, prometheus, loki all Running?
curl -s http://loki.monitoring.svc.cluster.local:3100/ready   # from the grafana pod:
kubectl -n monitoring exec deploy/monitoring-stack-grafana -c grafana -- curl -s http://loki.monitoring.svc.cluster.local:3100/ready
```

Datasources are provisioned from `deploy/argocd/monitoring.yaml` (`additionalDataSources`).
Health-check endpoints: Grafana → **Connections → Data sources → (Prometheus/Loki) → Save & test**.

### Loki ingestion failures / no logs in Explore

```bash
kubectl -n monitoring logs loki-0 --tail=50 | grep -iE 'level=(error|warn)'
kubectl -n monitoring logs -l app.kubernetes.io/name=alloy -c alloy --tail=50 | grep -iE 'level=(error|warn)'
```

- Alloy `timestamp too old` 400s right after startup → expected one-time bootstrap noise when
  positions are reset (Loki rejects samples older than the 168h retention window); they stop as
  soon as the tailer reaches the present.
- No logs at all → check Alloy discovery: `kubectl -n monitoring logs -l app.kubernetes.io/name=alloy -c alloy | grep -c 'start tailing file'`.

### Alloy failures

```bash
kubectl -n monitoring get pods -l app.kubernetes.io/name=alloy
kubectl -n monitoring logs -l app.kubernetes.io/name=alloy -c alloy --tail=50
# Config errors usually show as "could not perform the initial load successfully" — check
# deploy/argocd/alloy.yaml (only generally-available Alloy components are enabled by the chart).
```

### Persistent volume issues

```bash
kubectl get pvc -A                              # mongo-data-mongodb-0 (chat-app), storage-loki-0 (monitoring)
kubectl -n chat-app describe pvc mongo-data-mongodb-0
```

Kind uses the bundled `local-path-provisioner` (StorageClass `standard`). A `Lost`/`Failed` PVC on
Kind usually means the backing path disappeared after an EC2 restart with cluster recreation.
**Never delete PVCs** — MongoDB data lives in `mongo-data-mongodb-0`.

### Issues Faced and Fixes

### 1) Ingress hostname mismatch

### 1) Ingress hostname mismatch

* **Fix:** hosts are nip.io-based — `ingress.host` in `helm/chat-app/values-ec2.yaml` must be `chat.<PUBLIC_IP>.nip.io`. After an EC2 IP change run `scripts/update-ec2-endpoints.sh` (see [recovery](#ec2-restart--ip-change-recovery)).

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

* **Problem (historical):** Grafana showed a warning on the Loki datasource health check when Loki came from the old `loki-stack` chart.
* **Resolution:** fixed by the `loki` Helm chart 7.x single-binary deployment — the datasource health endpoint now returns `"Data source successfully connected"`. Query logs via **Grafana → Explore → Loki**, e.g. `{namespace="chat-app"}`.

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
* Implemented **centralized logging** using Loki and Grafana Alloy — logs from all pods searchable in Grafana, validated end-to-end including automatic discovery of restarted pods.
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
