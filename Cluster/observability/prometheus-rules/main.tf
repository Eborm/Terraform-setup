resource "helm_release" "prometheus_rules" {
  name      = "prometheus-rules"
  chart     = "${path.module}/config-chart"
  namespace = var.namespace

  create_namespace = false

  wait    = true
  atomic  = true
  timeout = 300
}