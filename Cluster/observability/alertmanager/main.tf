locals {
  alertmanager_config = yamlencode({
    route = {
      receiver        = "ntfy"
      group_by        = ["alertname", "namespace"]
      group_wait      = "30s"
      group_interval  = "5m"
      repeat_interval = "12h"

      routes = [
        {
          receiver = "ntfy"
          matchers = [
            "alertname =\"KubernetesContainerRestartingFrequently\""
          ]
          group_by = ["alertname", "namespace", "pod"]
        }
      ]
    }

    receivers = [
      {
        name = "ntfy"

        webhook_configs = [
          {
            url           = var.ntfy_url
            send_resolved = true

            http_config = {
              authorization = {
                type        = "Bearer"
                credentials = var.ntfy_alertmanager_token
              }
            }
          }
        ]
      }
    ]
  })
}

resource "kubernetes_secret_v1" "alertmanager_config" {
  metadata {
    name      = "alertmanager-main"
    namespace = var.namespace

    labels = {
      "app.kubernetes.io/name" = "alertmanager"
    }
  }

  type = "Opaque"

  data_wo = {
    "alertmanager.yaml" = local.alertmanager_config
  }

  # Update the write-only Secret whenever the configuration changes.
  data_wo_revision = parseint(
    substr(sha256(local.alertmanager_config), 0, 8),
    16
  )
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