resource "helm_release" "prometheus_operator" {
  name       = "prometheus-operator"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = var.chart_version

  namespace        = var.namespace
  create_namespace = false

  wait    = true
  atomic  = true
  timeout = 900

  values = [
    yamlencode({
      # Install the Prometheus Operator resource definitions.
      crds = {
        enabled = true
      }

      # Install the Operator itself.
      prometheusOperator = {
        enabled = true

        # We'll manage monitoring resources separately.
        serviceMonitor = {
          enabled = false
        }
      }

      # Do not install the other components through this release.
      prometheus = {
        enabled = false
      }

      alertmanager = {
        enabled = false
      }

      grafana = {
        enabled = false
      }

      kubeStateMetrics = {
        enabled = false
      }

      nodeExporter = {
        enabled = false
      }

      windowsMonitoring = {
        enabled = false
      }

      # The Operator-only release must not create the bundled
      # Kubernetes ServiceMonitors or default PrometheusRules.
      defaultRules = {
        create = false
      }

      kubelet = {
        enabled = false
      }

      kubeApiServer = {
        enabled = false
      }

      kubeControllerManager = {
        enabled = false
      }

      coreDns = {
        enabled = false
      }

      kubeEtcd = {
        enabled = false
      }

      kubeScheduler = {
        enabled = false
      }

      kubeProxy = {
        enabled = false
      }
    })
  ]
}