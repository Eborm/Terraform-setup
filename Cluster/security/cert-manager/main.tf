resource "kubernetes_namespace_v1" "cert_manager" {
  metadata {
    name = "cert-manager"
  }
}

resource "helm_release" "cert_manager" {
  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  version    = var.cert_manager_version

  namespace = kubernetes_namespace_v1.cert_manager.metadata[0].name

  create_namespace = false

  wait    = true
  atomic  = true
  timeout = 600

  values = [
    yamlencode({
      crds = {
        enabled = true
      }
    })
  ]

  depends_on = [
    kubernetes_namespace_v1.cert_manager
  ]
}

resource "kubernetes_secret_v1" "cloudflare" {
  metadata {
    name      = "cloudflare-api-token"
    namespace = kubernetes_namespace_v1.cert_manager.metadata[0].name
  }

  type = "Opaque"

  data_wo = {
    api-token = var.cloudflare_api_token
  }

  data_wo_revision = parseint(substr(sha256(var.cloudflare_api_token), 0, 8), 16)

  depends_on = [
    kubernetes_namespace_v1.cert_manager
  ]
}

resource "terraform_data" "wait_for_webhook" {
  depends_on = [
    helm_release.cert_manager
  ]

  provisioner "local-exec" {
    command = "kubectl --kubeconfig \"${var.kubeconfig_path}\" rollout status deployment/cert-manager-webhook --namespace cert-manager --timeout=300s"
  }
}

resource "helm_release" "cert_manager_config" {
  name = "cert-manager-config"

  chart = "${path.module}/config-chart"

  namespace = kubernetes_namespace_v1.cert_manager.metadata[0].name

  values = [
    yamlencode({
      cloudflareZone = var.cloudflare_zone
      acmeEmail      = var.acme_email
    })
  ]

  wait    = true
  atomic  = true
  timeout = 600

  depends_on = [
    terraform_data.wait_for_webhook,
    kubernetes_secret_v1.cloudflare
  ]
}