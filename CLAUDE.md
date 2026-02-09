# OpenZiti ZTNA — om-labs/ziti

## What This Repo Is

GitOps repo for OpenZiti ZTNA on buck-lab k8s. Controller + router deployed via Helm, images mirrored through Harbor, secrets in AKV `omlab-secrets`.

## Deployment Strategy

Gitea (source of truth) -> Gitea Actions CI (lint + image sync to Harbor) -> ArgoCD or deploy script -> k8s. GitHub is a push mirror.

## Key Patterns

- Helm values: base in `k8s/<component>/values.yaml`, overrides in `overlays/<cluster>/values.yaml`
- All scripts idempotent (`set -euo pipefail`, `helm upgrade --install`, `kubectl apply`)
- SOPS+age for any encrypted secrets in-repo
- Pod security: baseline enforce, restricted audit/warn
- Container hardening: runAsUser 2171 (ziggy), drop ALL caps, seccomp RuntimeDefault
- Storage: longhorn-r2 for persistent volumes
- Node placement: `om-labs.io/storage-node: "true"`
- Images: mirrored to Harbor (`harbor.buck-lab-k8s.omlabs.org:32632/openziti/`), never pulled from Docker Hub at runtime

## Hostnames (3-level for Cloudflare compat)

- Controller: `ziti-ctrl-buck.omlabs.org`
- Router: `ziti-router-buck.omlabs.org`

## Important

- ssl-passthrough on ingress-nginx is REQUIRED — OpenZiti does its own mTLS
- trust-manager must be configured with `app.trust.namespace=ziti` (not default cert-manager)
- CoreDNS hosts entry maps `ziti-ctrl-buck.omlabs.org` to controller ClusterIP for in-cluster enrollment
- Controller must be fully up before router enrollment
- Router enrollment JWT is one-time; the k8s secret preserves it for re-deploys
- Chart versions: ziti-controller 3.0.0 (app 1.7.2), ziti-router 2.0.0 (app 1.7.2)

## Bugs Encountered During Initial Deploy

- `runAsNonRoot` fails with non-numeric user `ziggy` — must set `runAsUser: 2171` explicitly
- trust-manager default trust namespace is cert-manager, not the release namespace — requires `app.trust.namespace=ziti`
- Controller ClusterIP changes on reinstall — CoreDNS hosts entry must be updated
- CF API token in AKV (`cloudflare-api-token`) lacks DNS record permissions for omlabs.org zone
