#!/usr/bin/env bash
#
# scripts/update-ec2-endpoints.sh
#
# Idempotent recovery tool for EC2 public-IP changes on the
# Cloud Native Chat Platform deployment.
#
# What it does
# ------------
# 1. Detects the current EC2 public IP via https://checkip.amazonaws.com
# 2. Generates nip.io hostnames:
#      ChatApp : chat.<IP>.nip.io
#      Grafana : grafana.<IP>.nip.io
#      ArgoCD  : <IP>.nip.io
# 3. Updates only the nip.io host lines in:
#      helm/chat-app/values-ec2.yaml           (ChatApp ingress host)
#      deploy/ingress/grafana-ingress.yaml     (Grafana ingress host)
#      deploy/ingress/argocd-ingress.yaml      (ArgoCD ingress host)
# 4. Applies the Grafana + ArgoCD ingresses live (not ArgoCD-managed, safe).
# 5. Patches the ChatApp ingress live for immediate availability.
# 6. --push: git pull --rebase, commit + push the 3 config files so ArgoCD
#    self-heal converges instead of reverting the ChatApp change.
# 7. Verifies hostnames resolve / respond and prints the final URLs.
#
# Safety
# ------
# - Replaces *.nip.io host lines only; unrelated IP addresses are never touched.
# - Fails hard if the public IP cannot be detected or does not look like IPv4.
# - Without --push nothing is committed to Git; the ChatApp hostname change is
#   temporary until ArgoCD's self-heal reverts it to the value committed in Git.
#
# Usage
# -----
#   bash scripts/update-ec2-endpoints.sh              # update files + apply live
#   bash scripts/update-ec2-endpoints.sh --push         # also commit & push
#
set -euo pipefail

PUSH=false
if [[ "${1:-}" == "--push" ]]; then
  PUSH=true
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

VALUES_FILE="helm/chat-app/values-ec2.yaml"
GRAFANA_INGRESS="deploy/ingress/grafana-ingress.yaml"
ARGOCD_INGRESS="deploy/ingress/argocd-ingress.yaml"

for f in "$VALUES_FILE" "$GRAFANA_INGRESS" "$ARGOCD_INGRESS"; do
  if [[ ! -f "$f" ]]; then
    echo "ERROR: required config file not found: $f" >&2
    exit 1
  fi
done

# --- 1. detect public IP ----------------------------------------------------
PUBLIC_IP="$(curl -s --max-time 10 https://checkip.amazonaws.com || true)"
if [[ -z "${PUBLIC_IP}" ]]; then
  echo "ERROR: could not retrieve public IP from https://checkip.amazonaws.com" >&2
  exit 1
fi
if [[ ! "$PUBLIC_IP" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]]; then
  echo "ERROR: retrieved value is not an IPv4 address: $PUBLIC_IP" >&2
  exit 1
fi

echo "Detected EC2 public IP: $PUBLIC_IP"

CHAT_HOST="chat.${PUBLIC_IP}.nip.io"
GRAFANA_HOST="grafana.${PUBLIC_IP}.nip.io"
ARGOCD_HOST="${PUBLIC_IP}.nip.io"

# --- 2. determine current hosts in config ----------------------------------
old_chat="$(grep -E 'host:' "$VALUES_FILE" | sed -E 's/.*host:[[:space:]]*//; s/[[:space:]]*$//' | head -1 || true)"
old_grafana="$(grep -E 'host:' "$GRAFANA_INGRESS" | sed -E 's/.*host:[[:space:]]*//; s/[[:space:]]*$//' | head -1 || true)"
old_argocd="$(grep -E 'host:' "$ARGOCD_INGRESS" | sed -E 's/.*host:[[:space:]]*//; s/[[:space:]]*$//' | head -1 || true)"

new_argocd="${PUBLIC_IP}.nip.io"

changed=false
if [[ "$old_chat" != "$CHAT_HOST" ]]; then changed=true; fi
if [[ "$old_grafana" != "$GRAFANA_HOST" ]]; then changed=true; fi
if [[ "$old_argocd" != "$ARGOCD_HOST" ]]; then changed=true; fi

sed -i -E "s/^(\s*host:\s*)chat\.[0-9.]+\.nip\.io/\1chat.${PUBLIC_IP}.nip.io/" "$VALUES_FILE"
sed -i -E "s/^(\s*host:\s*)grafana\.[0-9.]+\.nip\.io/\1grafana.${PUBLIC_IP}.nip.io/" "$GRAFANA_INGRESS"
sed -i -E "s/^(\s*host:\s*)[0-9.]+\.nip\.io/\1${PUBLIC_IP}.nip.io/" "$ARGOCD_INGRESS"

# Idempotency short-circuit
if [[ "$changed" == false ]]; then
  echo "Endpoints already up to date for IP $PUBLIC_IP (no file changes)."
else
  echo "Updated hosts:"
  [[ "$old_chat" != "$CHAT_HOST" ]] && echo "  ChatApp : $old_chat  ->  $CHAT_HOST   ($VALUES_FILE)"
  [[ "$old_grafana" != "$GRAFANA_HOST" ]] && echo "  Grafana : $old_grafana  ->  $GRAFANA_HOST   ($GRAFANA_INGRESS)"
  [[ "$old_argocd" != "$ARGOCD_HOST" ]] && echo "  ArgoCD  : $old_argocd  ->  $ARGOCD_HOST   ($ARGOCD_INGRESS)"
fi

# --- 4. apply live ingresses (Grafana + ArgoCD are not ArgoCD-managed) ----
kubectl apply -f "$GRAFANA_INGRESS" >/dev/null
kubectl apply -f "$ARGOCD_INGRESS" >/dev/null

# ChatApp ingress comes from the Helm chart via ArgoCD. Patch it live for
# immediate availability; warn that ArgoCD self-heal reverts it unless pushed.
kubectl patch ingress chat-app -n chat-app --type=merge \
  -p "{\"spec\":{\"rules\":[{\"host\":\"${CHAT_HOST}\"}]}}" >/dev/null 2>&1 \
  && echo "Patched live ChatApp ingress host -> $CHAT_HOST" \
  || echo "WARNING: could not patch live ChatApp ingress (apply manually or push to Git)"

# --- 5. verify -------------------------------------------------------------
verify() {
  local label="$1" url="$2" code
  code="$(curl -s -o /dev/null --max-time 10 -w '%{http_code}' "$url" || true)"
  if [[ "$code" =~ ^(200|301|302|401)$ ]]; then
    echo "  OK   $label -> $url  (HTTP $code)"
  else
    echo "  WARN $label -> $url  (HTTP $code — check ingress/pods are ready)"
  fi
}

echo "Verifying endpoints..."
verify "ChatApp"   "http://${CHAT_HOST}/"
verify "Grafana"   "http://${GRAFANA_HOST}/"
verify "ArgoCD"    "http://${ARGOCD_HOST}/"

echo
echo "Final application URLs:"
echo "  ChatApp : http://${CHAT_HOST}/"
echo "  Grafana : http://${GRAFANA_HOST}/"
echo "  ArgoCD  : http://${ARGOCD_HOST}/"

# --- 6. optional git push so ArgoCD converges -------------------------------
if [[ "$PUSH" == true ]]; then
  echo
  echo "Committing and pushing endpoint updates..."
  if [[ -n "$(git status --porcelain -- "$VALUES_FILE" "$GRAFANA_INGRESS" "$ARGOCD_INGRESS" 2>/dev/null)" ]]; then
    git pull --rebase --autostash || {
      echo "ERROR: git pull --rebase failed — resolve conflicts and retry --push" >&2
      exit 1
    }
    git add "$VALUES_FILE" "$GRAFANA_INGRESS" "$ARGOCD_INGRESS"
    git commit -m "chore(kind): update nip.io endpoints for IP ${PUBLIC_IP} [skip ci]" >/dev/null
    git push origin "HEAD:${GITHUB_REF_NAME:-restore-kind-gitops}"
    echo "Pushed endpoint updates; ArgoCD will sync chat-app ingress automatically."
  else
    echo "Nothing to commit — endpoints already matched IP $PUBLIC_IP."
  fi
else
  echo
  echo "NOTE: ChatApp ingress is GitOps-managed (ArgoCD self-heal). The live host"
  echo "      patch above will revert to the value committed in Git unless you run:"
  echo "        bash scripts/update-ec2-endpoints.sh --push"
fi
