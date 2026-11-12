
resource "helm_release" "alloy" {
  name       = "alloy"
  namespace  = var.namespace
  repository = "https://grafana.github.io/helm-charts"
  chart      = "alloy"
  version    = var.chart_version

  atomic  = true
  timeout = 600
  wait    = true

  values = [
    yamlencode({
      fullnameOverride = "alloy"

      alloy = {
        configMap = {
          create  = true
          content = file("${path.module}/config.alloy")
        }

        enableReporting = false
        storagePath     = "/tmp/alloy"
      }

      controller = {
        type     = "deployment"
        replicas = 1
      }

      rbac = {
        create = true

        rules = [
          {
            apiGroups = [""]
            resources = [
              "pods",
              "pods/log",
              "namespaces"
            ]
            verbs = [
              "get",
              "list",
              "watch"
            ]
          }
        ]
      }
    })
  ]
}
