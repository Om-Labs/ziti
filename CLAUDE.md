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

## Service Routing (ZTNA)

All internal services are routed through the Ziti overlay via nginx ingress:

```
Client → Ziti Desktop Edge → Ziti overlay → Router (host mode)
  → ingress-nginx-controller.ingress-nginx.svc:443 → backend
```

### Services (12 total)

| Service | Hostname | Port | Notes |
|---------|----------|------|-------|
| harbor | harbor.buck-lab-k8s.omlabs.org | 443 | |
| keycloak | auth-buck.omlabs.org | 443 | OIDC provider |
| longhorn | longhorn.buck-lab-k8s.omlabs.org | 443 | |
| mattermost | chat.focusjam.com | 443 | |
| minio-api | minio.buck-lab-k8s.omlabs.org | 443 | |
| minio-console | minio-console.buck-lab-k8s.omlabs.org | 443 | |
| slidee | slidee.focushive.com | 443 | |
| vaultwarden | vault.omlabs.org | 443 | |
| coder | coder.developerdojo.org | 443 | |
| gitea | buck-git.omlabs.org | 443 | |
| argocd | argocd-buck.omlabs.org | 443 | ssl-passthrough (gRPC) |
| gitea-ssh | buck-git.omlabs.org | 22 | Direct to gitea-ssh.gitea.svc:22 |

### Ziti Configs (13)

- 1 shared `host.v1` (nginx-ingress-host) — routes to nginx ingress ClusterIP:443
- 1 `host.v1` (gitea-ssh-host) — routes to gitea-ssh.gitea.svc:22
- 11 `intercept.v1` configs — one per service hostname

### Ziti Policies (4)

- **bind-all-services** (Bind) — `#routers` → `#internal-services`
- **dial-all-services** (Dial) — `#employees` → `#internal-services`
- **all-employees-all-routers** (edge-router-policy) — `#employees` → `#all` routers
- **all-services-all-routers** (service-edge-router-policy) — `#internal-services` → `#all` routers

### CoreDNS Entries (in-cluster resolution)

Required for services that do OIDC validation or cross-service calls:
- `auth-buck.omlabs.org` → nginx ingress ClusterIP
- `buck-git.omlabs.org` → nginx ingress ClusterIP
- `argocd-buck.omlabs.org` → nginx ingress ClusterIP

### Execution Order

1. Apply missing ingresses: `kubectl apply -f k8s/manifests/gitea-ingress.yaml -f k8s/manifests/argocd-ingress.yaml`
2. Patch CoreDNS: `kubectl apply -f k8s/manifests/coredns-patch.yaml`
3. Configure services: `scripts/configure_services.sh`
4. Create test identities: `scripts/create_identities.sh <name>`
5. Verify from enrolled laptop, then create remaining identities
6. Remove Cloudflare tunnel
7. (Later) Switch cert-manager to DNS-01

## Important

- ssl-passthrough on ingress-nginx is REQUIRED — OpenZiti does its own mTLS
- trust-manager must be configured with `app.trust.namespace=ziti` (not default cert-manager)
- CoreDNS hosts entry maps `ziti-ctrl-buck.omlabs.org` to controller ClusterIP for in-cluster enrollment
- Controller must be fully up before router enrollment
- Router enrollment JWT is one-time; the k8s secret preserves it for re-deploys
- Chart versions: ziti-controller 3.0.0 (app 1.7.2), ziti-router 2.0.0 (app 1.7.2)
- ArgoCD ingress requires `ssl-passthrough: "true"` (gRPC + HTTPS on same port)
- Gitea SSH goes direct to gitea-ssh.gitea.svc:22, not through nginx

## Bugs Encountered During Initial Deploy

- `runAsNonRoot` fails with non-numeric user `ziggy` — must set `runAsUser: 2171` explicitly
- trust-manager default trust namespace is cert-manager, not the release namespace — requires `app.trust.namespace=ziti`
- Controller ClusterIP changes on reinstall — CoreDNS hosts entry must be updated
- CF API token in AKV (`cloudflare-api-token`) lacks DNS record permissions for omlabs.org zone
