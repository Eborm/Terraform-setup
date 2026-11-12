# Kubernetes Persistent Storage

## Overview

Persistent Kubernetes storage is provided by TrueNAS through
the TrueNAS CSI driver.

The CSI driver dynamically provisions NFS-backed volumes from
the TrueNAS ZFS pool.

## TrueNAS configuration

| Setting | Value |
|---|---|
| TrueNAS address | 192.168.68.55 |
| ZFS pool | Storage |
| Dataset path | k8s/nfs |
| NFS server | 192.168.68.55 |
| NFS version | 4.1 |
| Compression | LZ4 |
| Sync | STANDARD |
| Root squash | Enabled |
| StorageClass | truenas-nfs |

The TrueNAS API is accessed over:

`wss://192.168.68.55/api/current`

Terraform uses a dedicated TrueNAS API key stored in a
Kubernetes Secret in the `truenas-csi` namespace.

The CA certificate is supplied to Terraform and used for
API certificate verification.

`insecure_skip_tls` defaults to false.

## TrueNAS CSI

The CSI driver is deployed into:

`truenas-csi`

The namespace has privileged Pod Security labels.

Terraform configures the CSI Helm release through a post-renderer.

The post-renderer has Bash and PowerShell implementations:

- `postrender-truenas-csi.sh`
- `postrender-truenas-csi.ps1`

The runtime is selected using `truenas_postrender_runtime`.

The default is Bash. Native Windows users can select PowerShell 7.

The Terraform default chart version in the uploaded configuration
is 1.4.0. Earlier deployment notes recorded 1.3.0 as the live
driver version. Verify the actual Helm release before upgrades.

## StorageClass

The driver creates a StorageClass named `truenas-nfs`.

| Setting | Value |
|---|---|
| Provisioner | TrueNAS CSI |
| Protocol | NFS |
| Default class | No |
| Reclaim policy | Retain |
| Volume expansion | Enabled |
| Binding mode | Immediate |
| Mount option | nfsvers=4.1 |
| Compression | LZ4 |
| Sync | STANDARD |
| Root squash | true |

The StorageClass is not the default class. PVCs must explicitly
request `truenas-nfs`.

## Current application volumes

| Application | PVC | Capacity | Access mode |
|---|---|---:|---|
| Grafana | grafana-data | 5 GiB | RWX |
| ntfy | ntfy-data | 2 GiB | RWX |
| CrowdSec | chart-managed data PVC | 1 GiB | RWO |
| CrowdSec | chart-managed config PVC | 100 MiB | RWO |

Prometheus and Alertmanager do not have explicit PVC configuration
in the supplied Prometheus and Alertmanager custom resources.

Do not assume their TSDB or notification state is persistent.

## NFS permissions

The NFS StorageClass enables root squash.

A container running as root inside Kubernetes must not be assumed
to have root privileges on the TrueNAS export.

Applications that write to NFS must use an identity compatible
with the dataset permissions.

ntfy currently runs as UID/GID 1000.

Grafana uses its existing claim and disables the Helm chart's
init-chown-data behavior.

Verify actual dataset ownership and ACLs before changing application
UIDs or GIDs.

## Reclaim policy

The StorageClass uses:

`Retain`

When a PVC is deleted, its PV and underlying TrueNAS data are
not automatically guaranteed to be deleted.

This protects data against some accidental deletion scenarios,
but it also means unused volumes can remain after an application
is removed.

Never delete retained PVs or TrueNAS datasets until their contents
and ownership have been reviewed.

## Verification commands

Run from the `Cluster` directory.

```bash
KUBECONFIG=../Infrastructure/kubeconfig kubectl get storageclass
```

```bash
KUBECONFIG=../Infrastructure/kubeconfig kubectl get pvc -A
```

```bash
KUBECONFIG=../Infrastructure/kubeconfig kubectl get pv
```

Inspect a particular volume:

```bash
KUBECONFIG=../Infrastructure/kubeconfig kubectl describe pvc ntfy-data -n ntfy
```

## Persistence testing

A separate TrueNAS test PVC was dynamically provisioned and
verified to retain data after pod recreation.

The ntfy PVC has been confirmed Bound and the ntfy application
has been confirmed healthy. A separate ntfy-specific pod
recreation test should be performed before describing ntfy's
recreation recovery as independently verified.

## Storage improvements

- Configure backups for application data.
- Monitor PVC capacity and storage consumption.
- Define a cleanup procedure for retained PVs.
- Document TrueNAS snapshot and replication policy.
- Test application-level restores, not only volume provisioning.
