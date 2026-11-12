resource "kubernetes_service_account_v1" "prometheus" {
  metadata {
    name      = "prometheus"
    namespace = var.namespace
  }
}

resource "kubernetes_cluster_role_v1" "prometheus" {
  metadata {
    name = "prometheus-server"
  }

  # Permission for Kubernetes service discovery and node metrics.
  rule {
    api_groups = [""]
    resources = [
      "nodes",
      "nodes/metrics",
      "services",
      "endpoints",
      "pods",
      "namespaces"
    ]
    verbs = ["get", "list", "watch"]
  }

  rule {
    api_groups = [""]
    resources  = ["configmaps"]
    verbs      = ["get"]
  }

  rule {
    api_groups = ["networking.k8s.io"]
    resources  = ["ingresses"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    non_resource_urls = ["/metrics"]
    verbs             = ["get"]
  }
}

resource "kubernetes_cluster_role_binding_v1" "prometheus" {
  metadata {
    name = "prometheus-server"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role_v1.prometheus.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.prometheus.metadata[0].name
    namespace = var.namespace
  }
}

# Internal access only. Grafana will use this Service later.
resource "kubernetes_service_v1" "prometheus" {
  metadata {
    name      = "prometheus"
    namespace = var.namespace

    labels = {
      "app.kubernetes.io/name" = "prometheus"
    }
  }

  spec {
    type = "ClusterIP"

    selector = {
      prometheus = "prometheus"
    }

    port {
      name        = "web"
      port        = 9090
      target_port = 9090
      protocol    = "TCP"
    }
  }
}

resource "helm_release" "prometheus" {
  name      = "prometheus"
  chart     = "${path.module}/config-chart"
  namespace = var.namespace

  create_namespace = false

  wait    = true
  atomic  = true
  timeout = 600

  values = [
    yamlencode({
      prometheus = {
        serviceAccountName      = kubernetes_service_account_v1.prometheus.metadata[0].name
        alertmanagerServiceName = "alertmanager-main"
        retention               = var.retention
        retentionSize           = var.retention_size
      }
    })
  ]

  depends_on = [
    kubernetes_cluster_role_binding_v1.prometheus,
    kubernetes_service_v1.prometheus
  ]
}