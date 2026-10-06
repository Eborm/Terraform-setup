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

resource "terraform_data" "wait_for_metallb_webhook" {
  triggers_replace = [
    helm_release.metallb.metadata.revision
  ]

  depends_on = [
    helm_release.metallb
  ]

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]

    command = <<-EOT
      KUBECONFIG="${path.root}/../Infrastructure/kubeconfig"

      echo "Waiting for MetalLB webhook..."

      for i in $(seq 1 60); do
        READY="$(
          kubectl \
            --kubeconfig "$KUBECONFIG" \
            get endpointslice \
            -n metallb-system \
            -l kubernetes.io/service-name=metallb-webhook-service \
            -o jsonpath='{range .items[*].endpoints[*]}{.conditions.ready}{"\n"}{end}' \
            2>/dev/null || true
        )"

        if echo "$READY" | grep -q '^true$'; then
          echo "MetalLB webhook is ready."
          exit 0
        fi

        echo "MetalLB webhook not ready yet ($i/60)..."
        sleep 5
      done

      echo "ERROR: MetalLB webhook did not become ready within 5 minutes."
      exit 1
    EOT
  }
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
    terraform_data.wait_for_metallb_webhook
  ]
}