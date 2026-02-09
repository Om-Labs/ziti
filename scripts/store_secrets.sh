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

log "Extracting controller root CA"
CTRL_POD=$(kubectl -n ziti get pod -l app.kubernetes.io/name=ziti-controller \
  -o jsonpath='{.items[0].metadata.name}')

ROOT_CA=$(kubectl -n ziti exec "$CTRL_POD" -- \
  cat /persistent/pki/cas/ctrl-plane-cas.crt 2>/dev/null || \
  kubectl -n ziti get secret ziti-controller-ctrl-plane-root-cert \
    -o jsonpath='{.data.tls\.crt}' 2>/dev/null | base64 -d || \
  echo "EXTRACT_FAILED")

if [[ "$ROOT_CA" == "EXTRACT_FAILED" ]]; then
  log "WARNING: Could not extract root CA — check controller PKI paths"
else
  log "Storing ziti-ctrl-root-ca in AKV ($AKV_NAME)"
  az keyvault secret set \
    --vault-name "$AKV_NAME" \
    --name "ziti-ctrl-root-ca" \
    --value "$ROOT_CA" \
    --output none
fi

# ---------- controller signing cert ------------------------------------------

log "Extracting controller signing cert"
SIGNING_CERT=$(kubectl -n ziti exec "$CTRL_POD" -- \
  cat /persistent/pki/signers/ctrl-plane-identity.crt 2>/dev/null || \
  kubectl -n ziti get secret ziti-controller-ctrl-plane-identity-cert \
    -o jsonpath='{.data.tls\.crt}' 2>/dev/null | base64 -d || \
  echo "EXTRACT_FAILED")

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
