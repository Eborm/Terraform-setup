# Component Inventory

This document records the configuration visible in Terraform and
the live versions observed during the deployment work.

Terraform chart versions are desired configuration values.
They should not automatically be treated as proof of the installed
runtime version.

## Networking

| Component | Namespace | Terraform chart version | Configuration |
|---|---|---:|---|
| Cilium | kube-system | 1.20.2 | CNI and kube-proxy replacement |
| MetalLB | metallb-system | 0.16.1 | Layer 2 LoadBalancer |

## Security

| Component | Namespace | Terraform chart version | Configuration |
|---|---|---:|---|
| cert-manager | cert-manager | 1.21.2 | ACME DNS-01 |
| CrowdSec | crowdsec | 0.24.2 | Log analysis and LAPI |
| Coraza | traefik | Local chart exists | WAF middleware |

The active Coraza middleware is currently defined by the Traefik
Helm release. The separate `security/coraza` module is not called
by the supplied `Cluster/main.tf`.

## Storage

| Component | Namespace | Terraform chart version | Configuration |
|---|---|---:|---|
| TrueNAS CSI | truenas-csi | 1.4.0 default | NFS provisioner |



## Ingress and applications

| Component | Namespace | Chart/image version | Configuration |
|---|---|---|---|
| Traefik | traefik | Chart 41.6.0 | Two replicas |
| ntfy | ntfy | Image v2.34.0 | One replica |
| whoami | demo | Image v1.10.3 | Two replicas |


## Observability

| Component | Namespace | Terraform chart version |
|---|---|---:|
| Prometheus Operator | monitoring | 92.11.0 |
| Node Exporter | node-exporter | 4.59.0 |
| kube-state-metrics | kube-state-metrics | 8.6.0 |
| Grafana | monitoring | 13.2.8 |
| Prometheus | monitoring | Local chart |
| Prometheus rules | monitoring | Local chart |
| Alertmanager | monitoring | Local chart |

The live Alertmanager logs showed application version 0.34.0.

Prometheus and Alertmanager are created through local Helm charts
and Prometheus Operator custom resources rather than separate
upstream application chart versions in the supplied Terraform.

## Kubernetes namespaces

| Namespace | Purpose | Pod Security labels in Terraform |
|---|---|---|
| kube-system | Cilium and Kubernetes system components | Managed by cluster |
| monitoring | Prometheus, Alertmanager, Grafana | No explicit labels in root |
| node-exporter | Node Exporter | privileged |
| kube-state-metrics | kube-state-metrics | No explicit labels in root |
| metallb-system | MetalLB | privileged |
| cert-manager | cert-manager | No explicit labels |
| traefik | Traefik ingress | No explicit labels |
| truenas-csi | TrueNAS CSI | privileged |
| crowdsec | CrowdSec | privileged |
| demo | whoami test app | No explicit labels |
| ntfy | ntfy | restricted |

The Pod Security labels shown here are those explicitly defined
in the supplied Terraform. They do not describe any additional
cluster-wide admission defaults configured outside this repository.
