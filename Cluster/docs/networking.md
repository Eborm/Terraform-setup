# Kubernetes Networking

## Overview

The cluster uses Cilium for pod networking, MetalLB for LAN
LoadBalancer IP advertisement and Traefik for ingress routing.

The main ingress IP is:

`192.168.68.190`

## Cilium

Cilium is installed through Helm in `kube-system`.

Configured chart version: `1.20.2`.

### Configuration

| Setting | Value |
|---|---|
| IPAM mode | kubernetes |
| kube-proxy replacement | true |
| Kubernetes API host | localhost |
| Kubernetes API port | 7445 |
| Operator replicas | 2 |
| Envoy | Disabled |
| Hubble | Disabled |
| BPF host legacy routing | Enabled |
| cgroup auto mount | Disabled |

Talos assigns PodCIDRs to Kubernetes nodes. Cilium uses Kubernetes
IPAM to obtain those addresses.

Cilium connects to the Talos KubePrism endpoint at `localhost:7445`.

The Cilium configuration disables kube-proxy replacement
compatibility concerns by explicitly enabling Cilium's
kube-proxy replacement.

The Cilium agent capability list is customized for Talos. It does
not request `SYS_MODULE`.

Hubble is currently disabled and can be considered as a separate
observability enhancement later.

Cilium Envoy is disabled because Traefik provides ingress.

## MetalLB

MetalLB runs in `metallb-system`.

Configured chart version: `0.16.1`.

The cluster uses native Layer 2 mode.

FRR and FRR-K8s are disabled.

### IPAddressPool

The local Helm configuration creates an IPAddressPool named
`ingress`.

Configured address:

`192.168.68.190/32`

Automatic assignment is disabled:

`autoAssign: false`

This avoids assigning the ingress IP to arbitrary LoadBalancer
services.

Services must explicitly request the address.

### L2Advertisement

An L2Advertisement named `ingress` advertises the `ingress`
IPAddressPool on the local network.

### Traefik LoadBalancer

Traefik requests the configured address using:

`metallb.io/loadBalancerIPs`

The Traefik service type is `LoadBalancer` and uses
`externalTrafficPolicy: Local`.

## Traefik

Traefik is the ingress controller and runs in the `traefik`
namespace.

Configured Helm chart version: `41.6.0`.

The deployment has two replicas.

The ingress class is enabled and configured as the default class.

The Kubernetes CRD and Ingress providers are enabled.
The Kubernetes Gateway provider and GatewayClass are disabled.

### Entry points

| Entry point | Container port | External port |
|---|---:|---:|
| web | 8000 | 80 |
| websecure | 8443 | 443 |

HTTP traffic on `web` is permanently redirected to HTTPS.

The `websecure` entrypoint enables TLS.

### Forwarded headers

Traefik trusts forwarded headers only from the Cloudflare IP
ranges configured in `services/traefik/main.tf`.

The configured list contains Cloudflare IPv4 and IPv6 ranges.

The list is hard-coded in Terraform and should be reviewed
periodically against Cloudflare's published ranges.

### Middleware chain

The HTTPS entrypoint applies:

1. `cloudflare-only`
2. `crowdsec-bouncer`
3. `coraza-waf-global`

This is the global middleware chain. Individual Ingress resources
do not need to repeat these middleware references.

### Access logs

Access logs are enabled in JSON format.

Headers are dropped by default, with `User-Agent` and
`Content-Type` retained.

CrowdSec agents read the Traefik access logs.

### TLS

Traefik uses the default TLS certificate Secret:

`bramwesel-me-tls`

The certificate is managed by cert-manager.

The requested names are:

- `bramwesel.me`
- `*.bramwesel.me`

### TrueNAS routing

Traefik also creates a Service and Endpoints resource for the
external TrueNAS host.

The backend uses HTTPS on port 443.

A ServersTransport named `truenas` supplies the TrueNAS CA bundle
and the expected server name.

## DNS

The Cloudflare API token is used by cert-manager for DNS-01
validation.

The supplied Terraform does not create Cloudflare DNS records.
DNS records for application hostnames must be managed separately.


