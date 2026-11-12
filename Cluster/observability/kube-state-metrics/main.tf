resource "helm_release" "kube_state_metrics" {
  name       = "kube-state-metrics"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-state-metrics"
  version    = var.chart_version

  namespace        = var.namespace
  create_namespace = false

  wait    = true
  atomic  = true
  timeout = 600

  values = [
    yamlencode({
      # Prometheus will discover this component through its ServiceMonitor.
      prometheusScrape = false

      service = {
        type = "ClusterIP"
        port = 8080
      }

      prometheus = {
        monitor = {
          enabled = true

          # Must match the selector configured on the Prometheus CR.
          additionalLabels = {
            release = "prometheus-operator"
          }

          http = {
            interval      = "30s"
            scrapeTimeout = "10s"

            # Preserve Kubernetes resource labels instead of
            # renaming conflicting labels to exported_namespace.
            honorLabels = true
          }
        }
      }

      resources = {
        requests = {
          cpu    = "50m"
          memory = "128Mi"
        }

        limits = {
          cpu    = "500m"
          memory = "512Mi"
        }
      }
    })
  ]
}