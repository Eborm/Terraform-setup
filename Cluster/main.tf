terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "3.2.1"
    }

    helm = {
      source  = "hashicorp/helm"
      version = "3.3.0"
    }

    time = {
      source  = "hashicorp/time"
      version = "0.14.2"
    }
  }
}

locals {
  kubeconfig = yamldecode(
    file(var.kubeconfig_path)
  )
}

resource "kubernetes_namespace_v1" "monitoring" {
  metadata {
    name = "monitoring"
  }
}

resource "kubernetes_namespace_v1" "node_exporter" {
  metadata {
    name = "node-exporter"

    labels = {
      "pod-security.kubernetes.io/enforce" = "privileged"
    }
  }
}

resource "kubernetes_namespace_v1" "kube_state_metrics" {
  metadata {
    name = "kube-state-metrics"
  }
}

provider "kubernetes" {
  host = local.kubeconfig.clusters[0].cluster.server

  cluster_ca_certificate = base64decode(
    local.kubeconfig.clusters[0].cluster["certificate-authority-data"]
  )

  client_certificate = base64decode(
    local.kubeconfig.users[0].user["client-certificate-data"]
  )

  client_key = base64decode(
    local.kubeconfig.users[0].user["client-key-data"]
  )
}

provider "helm" {
  kubernetes = {
    host = local.kubeconfig.clusters[0].cluster.server

    cluster_ca_certificate = base64decode(
      local.kubeconfig.clusters[0].cluster["certificate-authority-data"]
    )

    client_certificate = base64decode(
      local.kubeconfig.users[0].user["client-certificate-data"]
    )

    client_key = base64decode(
      local.kubeconfig.users[0].user["client-key-data"]
    )
  }
}

module "cilium" {
  source = "./networking/cilium"
}

module "metallb" {
  source = "./networking/metallb"

  depends_on = [
    module.cilium
  ]
}

module "cert_manager" {
  source = "./security/cert-manager"

  cert_manager_version = "1.21.2"
  kubeconfig_path      = var.kubeconfig_path

  cloudflare_api_token = var.cloudflare_api_token
  cloudflare_zone      = var.cloudflare_zone
  acme_email           = var.acme_email
}

module "traefik" {
  source = "./services/traefik"

  ingress_ip = "192.168.68.190"
  domain     = "bramwesel.me"

  crowdsec_bouncer_key = var.crowdsec_bouncer_key

  truenas_host      = "192.168.68.55"
  truenas_hostname  = "truenas.bramwesel.me"
  truenas_ca_bundle = var.truenas_ca_bundle

  coraza_engine_mode = "On"

  depends_on = [
    module.metallb,
    module.cert_manager,
    module.crowdsec
  ]
}

module "truenas_csi" {
  source = "./storage/truenas-csi"

  truenas_host           = "192.168.68.55"
  truenas_pool           = "Storage"
  truenas_api_key        = var.truenas_api_key
  insecure_skip_tls      = var.truenas_insecure_skip_tls
  truenas_ca_certificate = var.truenas_ca_bundle
  postrender_runtime     = var.truenas_postrender_runtime

  depends_on = [
    module.cilium
  ]
}

module "crowdsec" {
  source = "./security/crowdsec"

  crowdsec_bouncer_key = var.crowdsec_bouncer_key

  depends_on = [
    module.truenas_csi
  ]
}

module "test_app" {
  source = "./services/test-app"

  hostname = "whoami.bramwesel.me"

  depends_on = [
    module.traefik
  ]
}

module "prometheus_operator" {
  source = "./observability/prometheus-operator"

  namespace = kubernetes_namespace_v1.monitoring.metadata[0].name

  chart_version = "92.11.0"
}

module "node_exporter" {
  source = "./observability/node-exporter"

  namespace     = kubernetes_namespace_v1.node_exporter.metadata[0].name
  chart_version = "4.59.0"

  depends_on = [
    module.prometheus_operator
  ]
}

module "kube_state_metrics" {
  source = "./observability/kube-state-metrics"

  namespace     = kubernetes_namespace_v1.kube_state_metrics.metadata[0].name
  chart_version = "8.6.0"

  depends_on = [
    module.prometheus_operator
  ]
}

module "prometheus" {
  source = "./observability/prometheus"

  namespace      = kubernetes_namespace_v1.monitoring.metadata[0].name
  retention      = "7d"
  retention_size = "8GB"

  depends_on = [
    module.prometheus_operator,
    module.node_exporter,
    module.kube_state_metrics,
    module.alertmanager
  ]
}

module "alertmanager" {
  source = "./observability/alertmanager"

  namespace = kubernetes_namespace_v1.monitoring.metadata[0].name

  replicas  = 1
  retention = "120h"

  ntfy_url = "https://ntfy.bramwesel.me/alerts?template=alertmanager"

  ntfy_alertmanager_token = var.ntfy_alertmanager_token

  depends_on = [
    module.prometheus_operator,
    module.ntfy
  ]
}

module "prometheus_rules" {
  source = "./observability/prometheus-rules"

  namespace = kubernetes_namespace_v1.monitoring.metadata[0].name

  depends_on = [
    module.prometheus_operator,
    module.prometheus,
    module.alertmanager
  ]
}

module "grafana" {
  source = "./observability/grafana"

  namespace      = kubernetes_namespace_v1.monitoring.metadata[0].name
  hostname       = "grafana.bramwesel.me"
  chart_version  = "13.2.8"
  admin_password = var.grafana_admin_password

  depends_on = [
    module.prometheus,
    module.loki
  ]
}

module "grafana_dashboards" {
  source = "./observability/grafana-dashboards"

  namespace = kubernetes_namespace_v1.monitoring.metadata[0].name

  depends_on = [
    module.grafana
  ]
}

module "ntfy" {
  source = "./services/ntfy"

  hostname = "ntfy.bramwesel.me"

  ntfy_client_password_hash       = var.ntfy_client_password_hash
  ntfy_alertmanager_password_hash = var.ntfy_alertmanager_password_hash
  ntfy_alertmanager_token         = var.ntfy_alertmanager_token

  depends_on = [
    module.traefik,
    module.truenas_csi
  ]
}

module "loki" {
  source = "./observability/loki"

  namespace          = kubernetes_namespace_v1.monitoring.metadata[0].name
  storage_class_name = "truenas-nfs-loki"
  storage_size       = "10Gi"
  retention_period   = "168h"

  depends_on = [
    module.truenas_csi
  ]
}

module "alloy" {
  source = "./observability/alloy"

  namespace = kubernetes_namespace_v1.monitoring.metadata[0].name

  depends_on = [
    module.loki
  ]
}