locals {
  dashboard_files = fileset("${path.module}/dashboards", "*.json")
}

resource "kubernetes_config_map_v1" "dashboards" {
  for_each = local.dashboard_files

  metadata {
    name      = "grafana-dashboard-${trimsuffix(each.value, ".json")}"
    namespace = var.namespace

    labels = {
      grafana_dashboard = "1"
    }
  }

  data = {
    (each.value) = file("${path.module}/dashboards/${each.value}")
  }
}