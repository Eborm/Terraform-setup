# Observability Stack

## Overview

The monitoring stack consists of:

- Prometheus Operator.
- Prometheus.
- Alertmanager.
- Node Exporter.
- kube-state-metrics.
- Grafana.
- Terraform-managed Prometheus rules.
- Terraform-managed Grafana dashboards.
- ntfy notification delivery.

Prometheus and Alertmanager are separate resources managed through
Prometheus Operator custom resources.

## Prometheus Operator

Namespace: `monitoring`

Helm release: `prometheus-operator`

Chart: `kube-prometheus-stack`

Configured chart version: `92.11.0`.

The release installs the Prometheus Operator and CRDs.

The bundled Prometheus, Alertmanager, Grafana, Node Exporter and
kube-state-metrics components are disabled because they are
managed separately.

Default bundled rules and monitors are also disabled.

The chart is therefore used as an Operator/CRD installation rather
than as a complete monitoring stack.

## Prometheus

Namespace: `monitoring`

Prometheus is created through a local Helm chart that creates
a `monitoring.coreos.com/v1` Prometheus custom resource.

| Setting | Value |
|---|---|
| Name | prometheus |
| Replicas | 1 |
| Retention | 7d |
| Retention size | 8GB |
| Scrape interval | 30s |
| Evaluation interval | 30s |
| Admin API | Disabled |

Resource requests:

- CPU: 250m
- Memory: 1Gi

Resource memory limit:

- 2Gi

### Kubernetes RBAC

Prometheus uses a dedicated ServiceAccount.

The ClusterRole permits discovery through:

- Nodes.
- Node metrics.
- Services.
- Endpoints.
- Pods.
- Namespaces.
- ConfigMaps (get).
- Ingresses.
- Non-resource `/metrics`.

The ServiceAccount is bound through a ClusterRoleBinding.

### Target discovery

Prometheus discovers ServiceMonitors with:

`release=prometheus-operator`

It also discovers PodMonitors with:

`release=prometheus-operator`

The selectors allow discovery across namespaces.

PrometheusRule resources use the same release label.

### Alertmanager

Prometheus sends alerts to the Alertmanager service:

`alertmanager-main.monitoring`

The configured service port is `web` (9093).

Prometheus exposes an internal ClusterIP service on port 9090.

No public Prometheus Ingress is defined in the supplied configuration.

### Persistence

The Prometheus custom resource in the supplied configuration
does not define a storage volume or PVC.

Treat Prometheus TSDB data as non-persistent until a persistent
volume is explicitly configured and verified.

## Node Exporter

Namespace: `node-exporter`

Helm release: `node-exporter`

Chart: `prometheus-node-exporter`

Configured chart version: `4.59.0`.

Node Exporter exposes host-level metrics.

A ServiceMonitor is enabled.

The ServiceMonitor has:

`release=prometheus-operator`

Scrape interval: 30s.

Scrape timeout: 10s.

The namespace has a privileged Pod Security enforce label because
the exporter requires host-level access.

PrometheusScrape annotations are disabled; ServiceMonitor
discovery is used instead.

## kube-state-metrics

Namespace: `kube-state-metrics`

Helm release: `kube-state-metrics`

Configured chart version: `8.6.0`.

kube-state-metrics exposes Kubernetes object and workload state.

A ServiceMonitor is enabled with:

`release=prometheus-operator`

Scrape interval: 30s.

Scrape timeout: 10s.

Service type: ClusterIP.

Service port: 8080.

## Prometheus alert rules

The local `prometheus-rules` chart creates one PrometheusRule:

`cluster-alerts`

The rule resource has:

`release=prometheus-operator`

### Cluster availability

| Alert | Expression purpose | Duration | Severity |
|---|---|---:|---|
| PrometheusTargetDown | Scrape target is down | 5m | warning |
| KubernetesNodeNotReady | Node Ready condition false | 5m | critical |
| KubernetesPodCrashLooping | Container in CrashLoopBackOff | 5m | warning |
| KubernetesDeploymentReplicasMismatch | Available replicas differ from desired | 15m | warning |

### Node health

| Alert | Condition | Duration | Severity |
|---|---|---:|---|
| NodeHighCPU | CPU utilization above 90% | 15m | warning |
| NodeHighMemory | Memory utilization above 90% | 15m | warning |

These are the rules currently present in the supplied
`prometheus-rules/config-chart/values.yaml`.

Further production rules can be added after reviewing these
existing expressions and their behavior.

## Alertmanager

Namespace: `monitoring`

Alertmanager is created through a local Helm chart and an
Alertmanager custom resource.

| Setting | Value |
|---|---|
| Resource name | main |
| Replicas | 1 |
| Retention | 120h |
| Service | alertmanager-main |
| Port | 9093 |
| Service type | ClusterIP |

The observed live Alertmanager pod was:

`alertmanager-main-0`

It had two containers and was Ready 2/2 during verification.

The observed Alertmanager application version was 0.34.0.

### Configuration

The Kubernetes Secret is named:

`alertmanager-main`

The Secret contains:

`alertmanager.yaml`

The active default receiver is:

`ntfy`

The receiver posts webhooks to:

`https://ntfy.bramwesel.me/alerts?template=alertmanager`

Authentication uses a Bearer token belonging to the dedicated
ntfy Alertmanager user.

The token is held in a sensitive Terraform variable and
provisioned through the write-only Kubernetes Secret configuration.

### Notification grouping

| Setting | Value |
|---|---|
| Group by | alertname, namespace |
| Group wait | 30s |
| Group interval | 5m |
| Repeat interval | 12h |
| Send resolved | true |

### Persistence

The supplied Alertmanager custom resource does not define a
storage volume or PVC.

Alertmanager silence and notification state should therefore be
treated as non-persistent until explicit storage is configured
and verified.

## Grafana

Namespace: `monitoring`

Helm release: `grafana`

Chart repository: Grafana Community

Configured chart version: `13.2.8`.

Grafana runs one replica and uses the Recreate deployment strategy.

### Authentication

The administrator username is configured as `admin`.

The password is supplied through the sensitive Terraform variable:

`grafana_admin_password`

The Kubernetes Secret is:

`grafana-admin`

The Secret is provisioned using Terraform's write-only
`data_wo` attribute.

### Data source

Prometheus is configured as the default data source:

`http://prometheus.monitoring.svc.cluster.local:9090`

Access mode is proxy.

The data source is not editable through the Grafana UI.

### Persistence

PVC: `grafana-data`

Capacity: 5Gi

StorageClass: `truenas-nfs`

Access mode: `ReadWriteMany`

Grafana uses the pre-created claim.

The chart's init-chown-data behavior is disabled.

### Dashboard provisioning

A Grafana sidecar watches ConfigMaps in the `monitoring`
namespace.

The ConfigMap label is:

`grafana_dashboard=1`

The dashboard provider folder is:

`Kubernetes`

Dashboard ConfigMaps are created through the
`grafana-dashboards` Terraform module.

Current dashboard files:

- `kubernetes-cluster-overview.json`
- `kubernetes-workload-health.json`
- `kubernetes-persistent-storage.json`
- `prometheus-target-health.json`
- `talos-node-details.json`

The sidecar provider does not allow UI updates and watches
ConfigMaps for changes.

## ntfy notification delivery

ntfy runs in the `ntfy` namespace.

It receives Alertmanager notifications on the `alerts` topic.

The built-in ntfy Alertmanager template formats the webhook payload.

The Alertmanager token belongs to the restricted `alertmanager`
ntfy account.

The account is allowed to publish only to `alerts`.

## Verification already completed

The following tests were performed during deployment:

1. Prometheus Operator and Alertmanager resources were healthy.
2. Alertmanager reloaded the updated configuration.
3. The Alertmanager API reported a receiver named `ntfy`.
4. A synthetic firing alert was accepted by Alertmanager.
5. The firing notification arrived in ntfy.
6. A synthetic resolved alert was submitted repeatedly.
7. The resolved notification arrived in ntfy.
8. ntfy authentication and topic permissions passed their tests.

## Monitoring improvements

- Add explicit Prometheus persistence.
- Add explicit Alertmanager persistence.
- Review Prometheus rule coverage and thresholds.
- Add alert rules for critical storage and CSI failures.
- Decide whether CrowdSec metrics should be scraped.
- Add a backup strategy for Grafana dashboards and data.
- Review notification routing for severity and alert categories.
