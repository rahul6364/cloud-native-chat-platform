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
    * [Step 3: Option A - Manual Deployment](#step-3-option-a---manual-deployment)
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
* **Tunneling (demo):** Ngrok

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

---

## Project Structure

* `frontend/` - React app + `frontend/Dockerfile`
* `backend/` - API + socket server + auth
* `helm/chat-app/` - Helm chart (primary deployment)
  * `values.yaml` - image tags, ingress host, resources, sealed secret ciphertext
  * `templates/` - rendered Kubernetes resources (deployments, services, ingress, etc.)
* `k8s/` - legacy manifests and cluster utilities
  * `argocd.yml` - ArgoCD Application (points at `helm/chat-app`)
  * `pub-cert.pem` - kubeseal cluster cert for re-sealing secrets

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
git clone https://github.com/rahul6364/full-stack_chatApp.git
cd full-stack_chatApp
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

1. **Create `kind-config.yaml`**:
```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
```

2. **Spin up the cluster**:
```bash
kind create cluster --config kind-config.yaml
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

Since Sealed Secrets are encrypted with a key unique to each cluster, the existing `k8s/sealed-secrets.yaml` will NOT work on a fresh setup. Follow these steps to generate your own:

1. **Install the `kubeseal` CLI**:
   ```bash
   # Download and install the latest version for Linux/AMD64
   curl -Lo kubeseal-linux-amd64.tar.gz https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.36.1/kubeseal-0.36.1-linux-amd64.tar.gz
   tar -xvzf kubeseal-linux-amd64.tar.gz kubeseal
   sudo install -m 755 kubeseal /usr/local/bin/kubeseal
   ```

2. **Fetch the Cluster Certificate**:
   ```bash
   kubeseal --fetch-cert --controller-name=sealed-secrets --controller-namespace=kube-system > k8s/pub-cert.pem
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
     kubeseal --format yaml --cert k8s/pub-cert.pem > k8s/sealed-secrets.yaml
   ```

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
   You can apply the provided manifest directly to your cluster:
   ```bash
   kubectl apply -f k8s/argocd.yml
   ```
  *ArgoCD will now pull your code from GitHub and deploy the Helm chart from `helm/chat-app`.*

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

The application includes a full monitoring stack (Prometheus & Grafana) managed via ArgoCD.

1. **Deploy Monitoring**:
   The monitoring stack is defined in `k8s/monitoring-app.yml` and is automatically synced by ArgoCD into the `monitoring` namespace.

2. **Access Grafana**:
   ```bash
   kubectl port-forward -n monitoring svc/monitoring-stack-grafana 3000:80
   ```
   - **URL**: `http://localhost:3000`
   - **Login**: `admin`
   - **Password**: `admin123` (configured in `k8s/monitoring-app.yml`)

3. **Access Prometheus**:
   ```bash
   kubectl port-forward -n monitoring svc/monitoring-stack-kube-prom-prometheus 9090:9090
   ```
   - **URL**: `http://localhost:9090`

---

## Validation Checklist

- [ ] **Cluster Health**: `kubectl get nodes` (Ready)
- [ ] **ArgoCD App**: Status `Synced` & `Healthy` in UI.
- [ ] **Namespace**: `kubectl get pods -n chat-app` (All Running)
- [ ] **Ingress**: `kubectl get ingress -n chat-app` (Hostname chat-app.com visible)
- [ ] **Browser access** at `http://chat-app.com:8080/`.
- [ ] **Monitoring**: `kubectl get pods -n monitoring` (All Running)
- [ ] **Grafana Dashboard**: Accessible at `http://localhost:3000`.

---

## Issues Faced and Fixes

### 1) Ingress hostname mismatch
* **Fix:** set host in `k8s/ingress.yaml` to `chat-app.com`, add `127.0.0.1 chat-app.com` in hosts file.

### 2) Auth 401 on protected APIs after login
* **Fix:** use `NODE_ENV=development` in backend deployment for local Kind HTTP testing (cookies `secure: false`).

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
