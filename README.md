# Terraform Homelab Infrastructure

Terraform configuration for a Proxmox-hosted Talos Linux Kubernetes
homelab.

Repository: https://github.com/Eborm/Terraform-setup

Working branch: Kube-Prometheus-Stack

## Overview

The repository contains two independent Terraform roots:

| Directory | Responsibility |
|---|---|
| Infrastructure/ | Proxmox virtual machines and Talos Kubernetes bootstrap |
| Cluster/ | Kubernetes networking, security, storage, monitoring and applications |

The deployment order is:

```text
Proxmox
   |
   v
Talos Linux
   |
   v
Kubernetes
   |
   +-- Cilium
   +-- MetalLB
   +-- cert-manager
   +-- Traefik
   +-- CrowdSec
   +-- Coraza WAF
   +-- TrueNAS CSI
   +-- Prometheus
   +-- Alertmanager
   +-- Grafana
   +-- ntfy
```

## Documentation

### Infrastructure

- [Infrastructure overview](Infrastructure/README.md)
- [Proxmox setup and permissions](Infrastructure/Terraform.md)
- [Talos configuration](Infrastructure/talos-config/Talos.md)
- [Proxmox module notes](Infrastructure/Proxmox-update.md)

### Kubernetes Cluster

- [Cluster overview](Cluster/README.md)
- [Architecture](Cluster/docs/architecture.md)
- [Component inventory](Cluster/docs/inventory.md)
- [Networking](Cluster/docs/networking.md)
- [Security](Cluster/docs/security.md)
- [Storage](Cluster/docs/storage.md)
- [Observability](Cluster/docs/observability.md)
- [Services](Cluster/docs/services.md)
- [Operations](Cluster/docs/operations.md)
- [Backup and recovery](Cluster/docs/backup-and-recovery.md)
- [Troubleshooting](Cluster/docs/troubleshooting.md)

## Requirements

- Terraform
- Proxmox VE access
- Talos Linux-compatible virtual machines
- kubectl
- Helm provider access through Terraform
- TrueNAS SCALE with API access
- Cloudflare API token with the required DNS permissions
- Access to the cluster network

For WSL/Linux, Bash is used by default for the TrueNAS CSI Helm
post-renderer.

Native Windows users need PowerShell 7 and must configure
`truenas_postrender_runtime = "pwsh"`.

## Secrets and credentials

Each Terraform root uses its own variables.

Typical ignored secret files:

```text
Infrastructure/secrets.auto.tfvars
Cluster/secrets.auto.tfvars
```

Sensitive values include:

- Proxmox credentials
- Cloudflare API token
- TrueNAS API key
- TrueNAS CA certificate
- CrowdSec bouncer key
- Grafana administrator password
- ntfy password hashes and access token

Never commit:

- secrets.auto.tfvars
- kubeconfig
- Terraform state
- private keys
- API tokens
- generated credentials

Check `.gitignore` before adding files to Git.

## First deployment

The two Terraform roots have separate state.

Always apply Infrastructure before Cluster.

```bash
cd Infrastructure

terraform init
terraform fmt -recursive
terraform validate
terraform plan
terraform apply

cd ../Cluster

terraform init
terraform fmt -recursive
terraform validate
terraform plan
terraform apply
```

The Infrastructure root generates:

`Infrastructure/kubeconfig`

The Cluster root uses that file by default.

## Terraform workflow

For infrastructure changes:

1. Inspect the existing configuration.
2. Make one logical change.
3. Run terraform fmt.
4. Run terraform validate.
5. Review terraform plan.
6. Apply only after reviewing the plan.
7. Verify the deployed resources.
8. Update documentation.
9. Commit the change.

Never assume a successful Terraform apply proves that the application
is healthy. Check the Kubernetes resources and application behavior.

## Destruction order

When intentionally destroying the complete environment:

1. Destroy the Cluster root.
2. Destroy the Infrastructure root.

This prevents Kubernetes and Helm providers from attempting to access
a cluster that has already been removed.

Persistent volumes use Retain policies in the TrueNAS StorageClass.
Deleting Kubernetes resources does not necessarily delete their
underlying TrueNAS data.

Review storage resources before any destructive operation.
