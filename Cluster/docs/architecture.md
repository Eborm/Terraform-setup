# Cluster Architecture

## Overview

The homelab runs Kubernetes on seven Talos Linux virtual machines
hosted across three Proxmox nodes.

The cluster is divided into networking, ingress, security, storage,
monitoring and application services.

## Physical and virtual infrastructure

```text
Proxmox VE
|
+-- clanker-01
|   +-- cp-01
|   +-- wn-01
|   +-- wn-02
|
+-- clanker-02
|   +-- cp-02
|   +-- wn-03
|   +-- wn-04
|
+-- clanker-03
    +-- cp-03
```

The three control-plane VMs are distributed across the three
Proxmox hosts.

The four worker VMs are distributed across the first two Proxmox
hosts as defined in the Terraform configuration.

## Kubernetes control plane

The cluster name is `Homelab`.

The API endpoint is:

`https://192.168.68.95:6443`

The API virtual IP is configured by Talos.

The control plane is bootstrapped on cp-01, and the remaining
control-plane nodes are configured with the same Talos cluster
secrets.

The worker nodes join after the control-plane bootstrap.

## Networking architecture

```text
                 LAN / Internet
                       |
                       v
                   Cloudflare
                       |
                       v
                MetalLB address
                 192.168.68.190
                       |
                       v
                    Traefik
                       |
             HTTPS middleware chain
                       |
        +--------------+---------------+
        |              |               |
        v              v               v
      Grafana         ntfy          whoami
        |
        v
    Prometheus
        |
        v
   Alertmanager
        |
        v
       ntfy
```

Cilium provides pod networking and replaces kube-proxy.

MetalLB advertises the Traefik LoadBalancer IP using Layer 2 mode.

Traefik terminates HTTPS and routes requests to the internal
Kubernetes services.

## Ingress security path

The HTTPS entrypoint applies these middlewares in order:

1. Cloudflare IP allow-list.
2. CrowdSec bouncer.
3. Coraza WAF.

Only configured Cloudflare source ranges are accepted by the
global Cloudflare IP allow-list middleware.

Forwarded headers are trusted only from configured Cloudflare IP
ranges.

HTTP requests are redirected to HTTPS.

## Certificate flow

```text
Traefik Certificate
       |
       v
cert-manager
       |
       v
Let's Encrypt ClusterIssuer
       |
       v
Cloudflare DNS-01 challenge
       |
       v
bramwesel-me-tls Secret
       |
       v
Traefik default TLS store
```

The certificate requests:

- `bramwesel.me`
- `*.bramwesel.me`

The production issuer is configured as the Traefik certificate
issuer.

A staging issuer is also available for testing.

## Persistent storage architecture

```text
Kubernetes PVC
     |
     v
TrueNAS CSI provisioner
     |
     v
TrueNAS NFS server
192.168.68.55
     |
     v
ZFS pool: Storage
     |
     v
Dataset path: k8s/nfs
```

Applications explicitly request the `truenas-nfs` StorageClass.

The storage class uses NFS 4.1, LZ4 compression, standard sync
and root squash.

## Observability architecture

```text
Kubernetes Nodes
       |
       +--------------------+
       |                    |
       v                    v
 Node Exporter       kube-state-metrics
       |                    |
       +---------+----------+
                 |
                 v
             Prometheus
                 |
          Prometheus Rules
                 |
                 v
            Alertmanager
                 |
                 v
              ntfy
                 |
                 v
          ntfy client devices

Grafana
   |
   +---- Prometheus data source
   |
   +---- Terraform-provisioned dashboards
```

Prometheus scrapes targets discovered through ServiceMonitors
and PodMonitors carrying the `release=prometheus-operator` label.

Alertmanager receives alerts from Prometheus.

Alertmanager sends notifications to ntfy using an authenticated
webhook.

Grafana queries Prometheus through its internal ClusterIP service.

## Dependencies

The Terraform root establishes these important dependencies:

- MetalLB depends on Cilium.
- cert-manager is deployed before the Traefik certificate.
- TrueNAS CSI depends on Cilium.
- CrowdSec depends on TrueNAS CSI.
- Traefik depends on MetalLB, cert-manager and CrowdSec.
- The test application depends on Traefik.
- Node Exporter and kube-state-metrics depend on the Prometheus Operator.
- Prometheus depends on the Operator, exporters and Alertmanager.
- Prometheus rules depend on Prometheus and Alertmanager.
- Grafana depends on Prometheus.
- Grafana dashboards depend on Grafana.
- ntfy depends on Traefik and TrueNAS CSI.
- Alertmanager notification configuration depends on ntfy.

Terraform can schedule independent modules concurrently. The
dependencies above define the required ordering for connected
components.

## External dependencies

The cluster also depends on services outside Kubernetes:

- Proxmox VE for the VMs.
- TrueNAS for persistent storage.
- Cloudflare for DNS-01 validation and the public DNS/proxy path.
- Let's Encrypt for production certificates.
- The local LAN for Kubernetes node and LoadBalancer connectivity.

Cloudflare DNS records are not created by the supplied Terraform
configuration. External DNS records must be maintained separately.
