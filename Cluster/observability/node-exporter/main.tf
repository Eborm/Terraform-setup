resource "helm_release" "node_exporter" {
  name       = "node-exporter"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "prometheus-node-exporter"
  version    = var.chart_version

  namespace        = var.namespace
  create_namespace = false

  wait    = true
  atomic  = true
  timeout = 600

  values = [
    yamlencode({
      # We'll scrape through the ServiceMonitor, not service annotations.
      prometheusScrape = false

      service = {
        enabled  = true
        type     = "ClusterIP"
        portName = "metrics"
      }

      prometheus = {
        monitor = {
          enabled       = true
          interval      = "30s"
          scrapeTimeout = "10s"

          # This is the selector label the future Prometheus module
          # will use to discover our ServiceMonitors.
          additionalLabels = {
            release = "prometheus-operator"
          }
        }
      }

      resources = {
        requests = {
          cpu    = "25m"
          memory = "32Mi"
        }

        limits = {
          memory = "128Mi"
        }
      }
    })
  ]
}