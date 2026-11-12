# Cluster Services

## Overview

This document covers the application-facing services exposed
through the ingress controller.

## Traefik

Namespace: `traefik`

Helm chart version: `41.6.0`

Traefik runs two replicas and is the default IngressClass.

It exposes the following entrypoints:

| Entry point | External port | Purpose |
|---|---:|---|
| web | 80 | HTTP and HTTPS redirect |
| websecure | 443 | HTTPS |

The LoadBalancer IP is:

`192.168.68.190`

The IP is advertised by MetalLB.

The global HTTPS middleware chain is:

1. Cloudflare-only IP allow-list.
2. CrowdSec bouncer.
3. Coraza WAF.

The default TLS certificate is stored in:

`bramwesel-me-tls`

Traefik access logs are enabled in JSON format.

The dashboard and insecure API are disabled.

The deployment uses two replicas and topology spread constraints
to prefer distributing replicas across Kubernetes nodes.

### TrueNAS UI routing

Traefik also exposes TrueNAS through an IngressRoute.

Hostname:

`truenas.bramwesel.me`

Backend:

`192.168.68.148:443`

The backend uses HTTPS and a ServersTransport with the supplied
TrueNAS CA certificate.

## ntfy

Namespace: `ntfy`

Image:

`binwiederhier/ntfy:v2.34.0`

External URL:

`https://ntfy.bramwesel.me`

The application listens internally on port 8080.

The Kubernetes Service is a ClusterIP service on port 80.

### Deployment

- One replica.
- Recreate deployment strategy.
- TrueNAS-backed PVC.
- Read-only root filesystem.
- Non-root UID/GID 1000.
- Restricted Pod Security namespace.

### Persistent data

PVC:

`ntfy-data`

Size:

`2Gi`

StorageClass:

`truenas-nfs`

The volume stores ntfy's cache, attachment data and authentication
database.

ntfy uses a SQLite-backed database. Keep the deployment at one
replica when using this shared NFS-backed database arrangement.
RWX does not make a SQLite database safe for concurrent writers.

### Authentication

Anonymous access is denied.

| Account | Permissions |
|---|---|
| client | Read-only access to all topics |
| alertmanager | Write-only access to `alerts` |

The client password and Alertmanager password are supplied as
bcrypt hashes.

Alertmanager uses a dedicated access token.

The server configuration is stored in the
`ntfy-server-config` Kubernetes Secret.

### Health check

```bash
curl -i https://ntfy.bramwesel.me/v1/health
```

The deployment verification returned HTTP 200 and:

```json
{"healthy":true,"role":"active"}
```

### Authentication verification

| Test | Result |
|---|---:|
| Anonymous publish | 403 |
| Client read | 200 |
| Client publish | 403 |
| Alertmanager publish to alerts | 200 |
| Alertmanager publish to another topic | 403 |
| Alertmanager read | 403 |

All six tests passed.

## whoami test application

Namespace: `demo`

The test application uses:

`traefik/whoami:v1.10.3`

It runs two replicas.

The Service is internal and uses port 80.

The hostname is:

`whoami.bramwesel.me`

The application is useful for testing:

- Traefik ingress routing.
- TLS.
- Request headers.
- Client IP forwarding.
- Middleware behavior.

It is a diagnostic/test application rather than a production
application.

## Adding a new application

A typical application exposed through Traefik requires:

1. A dedicated namespace where appropriate.
2. A Deployment or Helm release.
3. A ClusterIP Service.
4. An Ingress or IngressRoute.
5. A hostname covered by the wildcard certificate.
6. Appropriate container security context.
7. A PVC when the application needs persistent data.

The global Traefik HTTPS middleware chain is applied through
the entrypoint.

Do not add another middleware reference without checking whether
the application needs additional protection or an exception.

## DNS records

The supplied Terraform does not create Cloudflare DNS records.

Create or maintain the required DNS records separately, pointing
the service hostnames through the intended Cloudflare/origin path.
