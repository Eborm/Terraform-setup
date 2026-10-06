# Terraform setup for Proxmox and Talos

This repository contains two separate Terraform roots for building a Talos Kubernetes cluster on Proxmox and installing Cilium:

- `Infrastructure/` provisions the Proxmox VMs and Talos cluster. It writes the generated Kubernetes kubeconfig to `Infrastructure/kubeconfig`.
- `Cluster/` reads a kubeconfig and installs Cilium with Helm.

The roots have separate Terraform state and must be run from their own directories. Terraform does not create an automatic dependency between them.

## Prerequisites

- Terraform installed and available on `PATH`
- Access to the Proxmox endpoint configured in `Infrastructure/main.tf`
- Proxmox credentials supplied through an ignored `Infrastructure/secrets.auto.tfvars` file or `TF_VAR_proxmox_username` and `TF_VAR_proxmox_password`
- A Talos-compatible Proxmox environment and the required provider access

Do not commit passwords, kubeconfigs, Terraform state, or other generated credentials. These files are ignored by Git. Review the provider versions in each root before changing them.

## First-time bootstrap

Run the roots in this order:

```text
Infrastructure -> Cluster
```

From the repository root:

```powershell
Set-Location Infrastructure
terraform init
terraform validate
terraform plan
terraform apply

Set-Location ..\Cluster
terraform init
terraform validate
terraform plan
terraform apply
```

The `Infrastructure` apply must finish first. Its `local_sensitive_file.kubeconfig` resource creates `Infrastructure/kubeconfig`; that file is the input used by the `Cluster` root. A fresh checkout does not contain the file, and planning `Cluster` before the first `Infrastructure` apply fails during kubeconfig loading. The `Cluster` variable validation reports this as a missing-file error instead of allowing a less clear provider error.

## Supplying another kubeconfig

The default input is `../Infrastructure/kubeconfig`, resolved while running Terraform from the `Cluster` directory. To use a different existing kubeconfig, pass its path explicitly:

```powershell
Set-Location Cluster
terraform plan -var='kubeconfig_path=C:\path\to\kubeconfig'
terraform apply -var='kubeconfig_path=C:\path\to\kubeconfig'
```

The supplied file must be a YAML kubeconfig containing cluster, user, certificate, and client-key data. Keep it outside Git and protect its permissions because it contains cluster credentials.

## Repository layout

```text
Infrastructure/
	main.tf                 Proxmox and Talos root
	talos-config/           Talos cluster configuration
	proxmox/                VM definitions
	kubeconfig              Generated, ignored kubeconfig

Cluster/
	main.tf                 Kubernetes and Helm providers
	networking/cilium/      Cilium Helm release
```

For detailed Proxmox permissions and Talos notes, see [Infrastructure/Terraform.md](Infrastructure/Terraform.md) and [Infrastructure/talos-config/Talos.md](Infrastructure/talos-config/Talos.md).

## Common commands

Run Terraform commands from the root being changed. Check the plan before applying it, especially when changing VM definitions or Cilium settings.

```powershell
terraform fmt -recursive
terraform validate
terraform plan
terraform apply
```

To destroy the environment, destroy `Cluster` first and `Infrastructure` second so the Kubernetes provider is not left pointing at removed infrastructure.
