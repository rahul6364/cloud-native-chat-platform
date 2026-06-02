# Sealed Secrets (cluster-specific)

Sealed Secret ciphertext lives in `helm/chat-app/values.yaml` under `sealedSecret.encryptedData`.

## Re-seal for a new cluster

```bash
kubeseal --fetch-cert \
  --controller-name=sealed-secrets \
  --controller-namespace=kube-system \
  > deploy/secrets/pub-cert.pem

kubectl create secret generic backend-secrets \
  --from-literal=cloudinary-cloud-name="$CLOUD_NAME" \
  --from-literal=cloudinary-api-key="$API_KEY" \
  --from-literal=cloudinary-api-secret="$API_SECRET" \
  --from-literal=jwt-secret="$JWT_SECRET" \
  --namespace chat-app \
  --dry-run=client -o json | \
  kubeseal --format yaml --cert deploy/secrets/pub-cert.pem > /tmp/backend-sealed.yaml
```

Copy `encryptedData` from `/tmp/backend-sealed.yaml` into `helm/chat-app/values.yaml`, then commit and sync ArgoCD.

`pub-cert.pem` is local-only (gitignored).
