resource "kubernetes_namespace_v1" "metallb" {
  metadata {
    name = "metallb-system"

    labels = {
      "pod-security.kubernetes.io/enforce" = "privileged"
      "pod-security.kubernetes.io/audit"   = "privileged"
      "pod-security.kubernetes.io/warn"    = "privileged"
    }
  }
}

resource "helm_release" "metallb" {
  name       = "metallb"
  repository = "https://metallb.github.io/metallb"
  chart      = "metallb"
  version    = var.metallb_version

  namespace = kubernetes_namespace_v1.metallb.metadata[0].name

  create_namespace = false

  wait    = true
  atomic  = true
  timeout = 600

  values = [
    yamlencode({
      # We are using native Layer 2 mode.
      frrk8s = {
        enabled = false
      }

      speaker = {
        frr = {
          enabled = false
        }
      }
    })
  ]

  depends_on = [
    kubernetes_namespace_v1.metallb
  ]
}

resource "helm_release" "metallb_config" {
  name = "metallb-config"

  chart = "${path.module}/config-chart"

  namespace = kubernetes_namespace_v1.metallb.metadata[0].name

  values = [
    yamlencode({
      ingressIP = var.ingress_ip
    })
  ]

  wait    = true
  atomic  = true
  timeout = 600

  depends_on = [
    helm_release.metallb
  ]
}