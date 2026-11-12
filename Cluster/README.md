# Kubernetes Cluster

## Overview

The `Cluster` directory is the Terraform root responsible for
deploying and managing the services inside the Talos Kubernetes
cluster.

The cluster currently consists of seven Kubernetes nodes:

- Three control-plane nodes.
- Four worker nodes.

The cluster is built on Talos Linux and uses Cilium for networking.

## Architecture and components

| Category | Component | Purpose |
|---|---|---|
| CNI | Cilium | Pod networking and kube-proxy replacement |
| Load balancing | MetalLB | LAN LoadBalancer addresses |
| Certificates | cert-manager | ACME DNS-01 certificates |
| Ingress | Traefik | HTTP and HTTPS routing |
| Security | CrowdSec | Log analysis and IP decisions |
| Security | Coraza | Web Application Firewall |
| Storage | TrueNAS CSI | Dynamic NFS volumes |
| Metrics | Prometheus | Metrics collection and alert evaluation |
| Alerting | Alertmanager | Alert grouping and notification delivery |
| Dashboards | Grafana | Monitoring visualization |
| Notifications | ntfy | Push notification delivery |
| Exporter | Node Exporter | Host metrics |
| Exporter | kube-state-metrics | Kubernetes object metrics |

## Terraform layout

```text
Cluster/
├── main.tf
├── variables.tf
│
├── networking/
│   ├── cilium/
│   └── metallb/
│
├── security/
│   ├── cert-manager/
│   ├── crowdsec/
│   └── coraza/
│
├── storage/
│   └── truenas-csi/
│
├── services/
│   ├── traefik/
│   ├── ntfy/
│   └── test-app/
│
├── observability/
│   ├── prometheus-operator/
│   ├── prometheus/
│   ├── prometheus-rules/
│   ├── alertmanager/
│   ├── grafana/
│   ├── grafana-dashboards/
│   ├── node-exporter/
│   └── kube-state-metrics/
│
└── docs/
```

## Documentation

- [Architecture](docs/architecture.md)
- [Component inventory](docs/inventory.md)
- [Networking](docs/networking.md)
- [Security](docs/security.md)
- [Storage](docs/storage.md)
- [Observability](docs/observability.md)
- [Services](docs/services.md)
- [Operations](docs/operations.md)
- [Backup and recovery](docs/backup-and-recovery.md)
- [Troubleshooting](docs/troubleshooting.md)

## Terraform provider versions

| Provider | Version |
|---|---|
| Kubernetes | 3.2.1 |
| Helm | 3.3.0 |
| Time | 0.14.2 |

The Time provider is declared in the root configuration; no Time
resources are currently visible in the supplied root configuration.

## Kubeconfig

The Cluster Terraform root uses:

`../Infrastructure/kubeconfig`

When running kubectl from the `Cluster` directory, explicitly
specify the kubeconfig:

```bash
KUBECONFIG=../Infrastructure/kubeconfig kubectl get nodes
```

This is the standard Kubernetes command convention for this project.

## Deployment workflow

Run Terraform commands from the `Cluster` directory:

```bash
terraform fmt -recursive
terraform validate
terraform plan
terraform apply
```

Always inspect the plan before applying.

The Cluster root depends on the Infrastructure root having already
created a working Kubernetes cluster and kubeconfig.

## Important storage behavior

The TrueNAS StorageClass uses:

- NFS.
- ReadWriteMany support.
- Root squash.
- Retain reclaim policy.
- Volume expansion enabled.

A Retain reclaim policy means that deleting a PVC does not imply
that the underlying TrueNAS dataset will be deleted.

Review persistent volumes before deleting applications or storage
resources.
