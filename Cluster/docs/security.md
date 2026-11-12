# Cluster Security

## Overview

Security is implemented through several layers:

- Talos Linux as the Kubernetes operating system.
- Kubernetes Pod Security Admission labels.
- Cilium networking.
- Cloudflare source IP filtering.
- TLS certificates through cert-manager.
- CrowdSec threat decisions.
- Coraza WAF.
- Kubernetes Secrets.
- Restricted application container security contexts.

## cert-manager

cert-manager runs in the `cert-manager` namespace.

Configured chart version: `1.21.2`.

The Helm release installs cert-manager CRDs.

### Cloudflare DNS-01

A Kubernetes Secret named `cloudflare-api-token` contains the
Cloudflare API token.

Terraform provisions this Secret through the write-only
`data_wo` attribute.

The Secret is used by two ClusterIssuers:

| ClusterIssuer | ACME server |
|---|---|
| letsencrypt-staging | Let's Encrypt staging |
| letsencrypt-production | Let's Encrypt production |

Both use DNS-01 validation through Cloudflare.

The DNS zone and ACME email are Terraform inputs.

### Wildcard certificate

Traefik requests a certificate for:

- `bramwesel.me`
- `*.bramwesel.me`

The generated Secret is:

`traefik/bramwesel-me-tls`

The certificate uses the production ClusterIssuer by default.

The cert-manager webhook readiness is checked through a Terraform
local-exec provisioner using the configured kubeconfig path.

## Cloudflare filtering

Traefik contains a Cloudflare IP allow-list middleware.

It rejects requests whose source IP is not within the configured
Cloudflare IPv4 or IPv6 ranges.

The configured reject status is HTTP 403.

The same Cloudflare ranges are used as trusted forwarded-header
sources.

Direct requests to the origin that bypass Cloudflare are therefore
not expected to pass this middleware.

Cloudflare IP ranges are hard-coded in Terraform and should be
reviewed when Cloudflare changes its published ranges.

## CrowdSec

CrowdSec runs in the `crowdsec` namespace.

Configured Helm chart version: `0.24.2`.

The deployment contains:

- Local API (LAPI).
- CrowdSec agent.
- Traefik bouncer integration.

The agent reads Kubernetes container logs through host
`/var/log`.

The agent is configured to acquire Traefik pod logs from the
`traefik` namespace using the `traefik` program.

The `crowdsecurity/traefik` collection is configured.

The LAPI has one replica and an internal ClusterIP service.

### Persistent volumes

| Volume | Size | Access mode |
|---|---:|---|
| CrowdSec data | 1 GiB | ReadWriteOnce |
| CrowdSec config | 100 MiB | ReadWriteOnce |

Both use the `truenas-nfs` StorageClass.

### Bouncer

The Traefik bouncer key is stored in a Kubernetes Secret.

The key is mounted into Traefik at:

`/etc/traefik/crowdsec/BOUNCER_KEY_traefik`

The bouncer connects to:

`crowdsec-service.crowdsec.svc.cluster.local:8080`

The configured mode is `stream`.

The namespace has privileged Pod Security labels because the
agent needs host log access.

CrowdSec metrics are enabled, but its ServiceMonitor and
PodMonitor creation are disabled in the supplied values.
Prometheus therefore does not automatically discover those
metrics through these resources.

## Coraza WAF

Traefik loads the Coraza plugin:

`github.com/jcchavezs/coraza-http-wasm-traefik`

Configured plugin version: `v0.3.0`.

The global middleware is named:

`coraza-waf-global`

It includes:

- Coraza engine mode `On`.
- CRS setup configuration.
- OWASP Core Rule Set configuration.
- Debug logging to standard output at level 3.

The engine mode is supplied through the Traefik module variable
`coraza_engine_mode`.

The current root configuration sets it to `On`.

### Standalone Coraza module

A separate module exists at `security/coraza`.

It defines a local Helm chart for a Coraza Middleware, with a
default engine mode of `DetectionOnly`.

The supplied `Cluster/main.tf` does not instantiate that module.
The active global Coraza middleware is currently created inside
the Traefik Helm release.

Avoid assuming that changing the standalone module changes the
currently active global middleware.

## Kubernetes Pod Security

The supplied Terraform explicitly applies these Pod Security labels:

| Namespace | Enforce | Audit | Warn |
|---|---|---|---|
| metallb-system | privileged | privileged | privileged |
| truenas-csi | privileged | privileged | privileged |
| crowdsec | privileged | privileged | privileged |
| node-exporter | privileged | not explicitly set | not explicitly set |
| ntfy | restricted | restricted | restricted |

The privileged namespaces require review because they allow
workloads to request security capabilities that restricted
namespaces would reject.

The exact requirements should be reviewed when upgrading their
charts.

### ntfy container security

ntfy is configured to run as a non-root user.

Its security context includes:

- `runAsNonRoot: true`
- UID 1000
- GID 1000
- `allowPrivilegeEscalation: false`
- `readOnlyRootFilesystem: true`
- Drop all Linux capabilities.
- Seccomp RuntimeDefault.
- No service account token automount.

## Kubernetes Secrets

Sensitive configuration is managed through Kubernetes Secrets.

Examples include:

- Cloudflare API token.
- CrowdSec bouncer key.
- TrueNAS API key.
- TrueNAS CA certificate.
- Grafana administrator password.
- ntfy server authentication configuration.
- Alertmanager webhook token.

Where supported, Terraform uses `data_wo` and
`data_wo_revision` for write-only Secret values.

Terraform state is still sensitive and must be protected.

Never print secret values into terminal logs, commit them to Git,
or include them in documentation.

## Known security improvements

1. Replace Proxmox provider `insecure = true` with certificate
   verification.
2. Review privileged namespace requirements.
3. Review Cloudflare IP ranges periodically.
4. Review Coraza logs and false-positive behavior.
5. Establish a backup and rotation process for all API tokens.
6. Verify that all Terraform state storage is protected.
