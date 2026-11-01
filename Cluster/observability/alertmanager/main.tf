resource "kubernetes_secret_v1" "alertmanager_config" {
  metadata {
    name      = "alertmanager-main"
    namespace = var.namespace

    labels = {
      "app.kubernetes.io/name" = "alertmanager"
    }
  }

  type = "Opaque"

  # Minimal valid configuration for the initial installation.
  # The empty receiver deliberately discards notifications until
  # a real notification receiver is configured.
  data = {
    "alertmanager.yaml" = yamlencode({
      route = {
        receiver        = "discard"
        group_by        = ["alertname", "namespace"]
        group_wait      = "30s"
        group_interval  = "5m"
        repeat_interval = "12h"
      }

      receivers = [
        {
          name = "discard"
        }
      ]
    })
  }
}

resource "helm_release" "alertmanager" {
  name      = "alertmanager"
  chart     = "${path.module}/config-chart"
  namespace = var.namespace

  create_namespace = false

  wait    = true
  atomic  = true
  timeout = 600

  values = [
    yamlencode({
      alertmanager = {
        name         = "main"
        replicas     = var.replicas
        retention    = var.retention
        configSecret = kubernetes_secret_v1.alertmanager_config.metadata[0].name

        resources = {
          requests = {
            cpu    = "50m"
            memory = "128Mi"
          }

          limits = {
            memory = "256Mi"
          }
        }
      }
    })
  ]

  depends_on = [
    kubernetes_secret_v1.alertmanager_config
  ]
}

resource "kubernetes_service_v1" "alertmanager" {
  metadata {
    name      = "alertmanager-main"
    namespace = var.namespace
  }

  spec {
    type = "ClusterIP"

    selector = {
      alertmanager = "main"
    }

    port {
      name        = "web"
      port        = 9093
      target_port = "web"
      protocol    = "TCP"
    }
  }

  depends_on = [
    helm_release.alertmanager
  ]
}