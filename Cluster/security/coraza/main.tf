resource "helm_release" "coraza_config" {
  name  = "coraza-config"
  chart = "${path.module}/config-chart"

  namespace        = var.traefik_namespace
  create_namespace = false

  wait    = true
  atomic  = true
  timeout = 300

  values = [
    yamlencode({
      middlewareName = var.middleware_name
      engineMode     = var.engine_mode
    })
  ]
}