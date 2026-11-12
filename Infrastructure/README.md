# Infrastructure

## Overview

This Terraform root provisions the virtual machines on Proxmox and
configures Talos Linux to bootstrap the Kubernetes cluster.

It is responsible for the underlying Kubernetes infrastructure,
not the applications deployed inside Kubernetes.

## Proxmox environment

| Setting | Value |
|---|---|
| Proxmox endpoint | https://192.168.68.180:8006/ |
| Hypervisor nodes | clanker-01, clanker-02, clanker-03 |
| VM network bridge | vmbr0 |
| VM network model | e1000 |
| VM datastore | local-lvm |
| Talos installation disk | /dev/sda |
| Talos installer ISO | local:iso/talos-nocloud-amd64-with-qemu.iso |

The Proxmox provider is pinned to version 0.113.1.

The provider currently has `insecure = true`. This disables TLS
certificate verification for the Proxmox API connection. It is a
known security exception and should be replaced with proper
certificate validation when practical.

Proxmox access uses a dedicated Terraform user and role. Refer to
[Terraform.md](Terraform.md) for the existing permission instructions.

## Virtual machines

The Proxmox module defines three control-plane virtual machines
and four worker virtual machines.

### Control plane

| VM | Proxmox host | IP address | CPU | Memory | Disk |
|---|---|---|---:|---:|---:|
| cp-01 | clanker-01 | 192.168.68.191 | 2 | 4 GiB | 40 GiB |
| cp-02 | clanker-02 | 192.168.68.192 | 2 | 4 GiB | 40 GiB |
| cp-03 | clanker-03 | 192.168.68.193 | 2 | 4 GiB | 40 GiB |

The control-plane IP and MAC addresses are defined in
`proxmox/main.tf`.

### Worker nodes

| VM | Proxmox host | CPU | Memory | Disk |
|---|---|---:|---:|---:|
| wn-01 | clanker-01 | 4 | 14 GiB | 50 GiB |
| wn-02 | clanker-01 | 4 | 14 GiB | 50 GiB |
| wn-03 | clanker-02 | 2 | 12 GiB | 50 GiB |
| wn-04 | clanker-02 | 2 | 12 GiB | 50 GiB |

Worker addresses are discovered using the QEMU guest agent.

The Talos worker configuration selects an address beginning with
`192.168.68.`. Verify that the selected address is the intended
management/LAN address.

### VM configuration

All VMs use:

- QEMU guest agent enabled.
- Host CPU type.
- No memory ballooning.
- Talos NoCloud installer media.
- VirtIO QEMU agent support included in the Talos installer image.
- `vmbr0` network bridge.
- e1000 virtual network adapter.

## Talos Linux

| Setting | Value |
|---|---|
| Cluster name | Homelab |
| Talos version | v1.13.0 |
| Talos provider | 0.11.0 |
| Kubernetes API VIP | 192.168.68.95 |
| Kubernetes API port | 6443 |
| API endpoint | https://192.168.68.95:6443 |
| Installation disk | /dev/sda |

Talos machine secrets are generated through the Talos provider.

The control-plane configuration is applied to all three control-plane
nodes. Kubernetes is bootstrapped through cp-01.

The worker configurations are applied after bootstrap.

### Network configuration

The Talos machine configuration:

- Uses DHCP on the physical network interface.
- Configures the Kubernetes API virtual IP.
- Disables the default CNI configuration.
- Disables kube-proxy.

Cilium is installed later by the Cluster Terraform root.

### Kubeconfig generation

After Kubernetes bootstrap, the Talos provider retrieves the
cluster kubeconfig.

Terraform writes it to:

`Infrastructure/kubeconfig`

The file permission is set to `0600`.

The kubeconfig is a sensitive credential and must not be committed.

## Terraform providers

| Provider | Version |
|---|---|
| bpg/proxmox | 0.113.1 |
| siderolabs/talos | 0.11.0 |

## Terraform state

Infrastructure and Cluster are separate Terraform roots.

Do not share or copy the state files between the two roots.

No remote backend is declared in the supplied Terraform
configuration. The default local backend is therefore used unless
the backend configuration is changed separately.

Protect state files because Terraform state can contain sensitive
resource data.

## Deployment order

```text
Infrastructure
    |
    v
Proxmox VMs
    |
    v
Talos machine configuration
    |
    v
Control-plane bootstrap
    |
    v
Worker nodes join
    |
    v
Kubeconfig generated
    |
    v
Cluster Terraform root
```

See also:

- [Proxmox permissions](Terraform.md)
- [Talos configuration notes](talos-config/Talos.md)
- [Proxmox module notes](Proxmox-update.md)
