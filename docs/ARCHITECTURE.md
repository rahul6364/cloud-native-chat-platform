# Architecture

## Current Architecture (Kind on EC2)

- **Cluster:** Single-node Kind cluster running inside Docker on an Ubuntu EC2 host.
- **Ingress:** `ingress-nginx` routing host-based HTTP and WebSocket traffic (`nip.io` hostnames).
- **Application (`chat-app` namespace):**
  - **Frontend:** React SPA served by Nginx (`ClusterIP`), proxying `/api` and `/socket.io` when accessed via service.
  - **Backend:** Node.js/Express REST API + Socket.IO server (`ClusterIP`), exposing `/health` and `/metrics` (`prom-client`).
  - **Socket.IO Scaling:** Uses `@socket.io/redis-adapter` with in-cluster Redis and `websocket`-only transport so replicas share state without sticky sessions.
  - **Database:** MongoDB StatefulSet (`mongo:7.0`) with a 1Gi PVC.
- **GitOps:** ArgoCD (health endpoint `/healthz`) watches `restore-kind-gitops`. The application ArgoCD `Application` is named `chatapp` (manifest: `deploy/argocd/chat-app.yaml`) and renders `helm/chat-app` with `values-ec2.yaml`.
- **Observability (`monitoring` namespace):** Prometheus Operator (`kube-prometheus-stack`), Grafana, Loki (SingleBinary), and Grafana Alloy DaemonSet.
- **CI/CD:** GitHub Actions runs Gitleaks, ESLint, CodeQL, Docker builds, Trivy scans, pushes to Docker Hub, and bumps `frontend`/`backend` image tags in `helm/chat-app/values-ec2.yaml` on `restore-kind-gitops` (and `values-eks.yaml` on `main`).

## Target EKS Architecture

- **Cluster & Storage:** Amazon EKS with EBS CSI driver (`gp3` `StorageClass`, `reclaimPolicy: Delete`).
- **Ingress:** AWS Load Balancer Controller (`ingressClassName: alb`, `internet-facing`, `target-type: ip`, `idle_timeout.timeout_seconds=3600`), with per-service healthcheck annotations (`/` on frontend, `/health` on backend).
- **Networking:** `NetworkPolicy` enabled with `albCidr` matching the Terraform VPC CIDR.
- **Secrets & Images:** ExternalSecrets Operator replacing SealedSecrets; container images pulled from Amazon ECR.
- **Scaling & Availability:** HPA (2–5 replicas at 70% CPU) and PodDisruptionBudgets enabled for `frontend` and `backend`.
