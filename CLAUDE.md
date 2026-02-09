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
- Container hardening: non-root, drop ALL caps, seccomp RuntimeDefault
- Storage: longhorn-r2 for persistent volumes
- Node placement: `om-labs.io/storage-node: "true"`
- Images: mirrored to Harbor, never pulled from Docker Hub at runtime

## Important

- ssl-passthrough on ingress-nginx is REQUIRED — OpenZiti does its own mTLS
- Controller must be fully up before router enrollment
- Router enrollment JWT is one-time; the k8s secret preserves it for re-deploys
