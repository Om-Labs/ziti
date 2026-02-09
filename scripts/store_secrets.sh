#!/usr/bin/env bash
set -euo pipefail

# Extract OpenZiti secrets from k8s and store in Azure Key Vault.
# Idempotent — overwrites existing AKV secrets on each run.
#
# Prerequisites:
#   - az cli logged in with write access to the vault
#   - Controller deployed and running in the ziti namespace

AKV_NAME="${AKV_NAME:-omlab-secrets}"

log() { echo "==> $*"; }

# ---------- admin password ---------------------------------------------------

log "Extracting admin password"
ADMIN_PW=$(kubectl -n ziti get secret ziti-controller-admin-secret \
  -o jsonpath='{.data.admin-password}' | base64 -d)

log "Storing ziti-admin-password in AKV ($AKV_NAME)"
az keyvault secret set \
  --vault-name "$AKV_NAME" \
  --name "ziti-admin-password" \
  --value "$ADMIN_PW" \
  --output none

# ---------- controller root CA -----------------------------------------------

log "Extracting controller root CA (edge-root-secret)"
ROOT_CA=$(kubectl -n ziti get secret ziti-controller-edge-root-secret \
  -o jsonpath='{.data.tls\.crt}' | base64 -d 2>/dev/null || echo "EXTRACT_FAILED")

if [[ "$ROOT_CA" == "EXTRACT_FAILED" ]]; then
  log "WARNING: Could not extract root CA — check controller PKI"
else
  log "Storing ziti-ctrl-root-ca in AKV ($AKV_NAME)"
  az keyvault secret set \
    --vault-name "$AKV_NAME" \
    --name "ziti-ctrl-root-ca" \
    --value "$ROOT_CA" \
    --output none
fi

# ---------- controller signing cert ------------------------------------------

log "Extracting controller signing cert (edge-signer-secret)"
SIGNING_CERT=$(kubectl -n ziti get secret ziti-controller-edge-signer-secret \
  -o jsonpath='{.data.tls\.crt}' | base64 -d 2>/dev/null || echo "EXTRACT_FAILED")

if [[ "$SIGNING_CERT" == "EXTRACT_FAILED" ]]; then
  log "WARNING: Could not extract signing cert — check controller PKI paths"
else
  log "Storing ziti-ctrl-signing-cert in AKV ($AKV_NAME)"
  az keyvault secret set \
    --vault-name "$AKV_NAME" \
    --name "ziti-ctrl-signing-cert" \
    --value "$SIGNING_CERT" \
    --output none
fi

log "Done — secrets stored in AKV ($AKV_NAME)"
