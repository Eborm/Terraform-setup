resource "kubernetes_namespace_v1" "truenas_csi" {
  metadata {
    name = "truenas-csi"

    labels = {
      "pod-security.kubernetes.io/enforce" = "privileged"
      "pod-security.kubernetes.io/audit"   = "privileged"
      "pod-security.kubernetes.io/warn"    = "privileged"
    }
  }
}

resource "kubernetes_secret_v1" "truenas_api" {
  metadata {
    name      = "truenas-api-credentials"
    namespace = kubernetes_namespace_v1.truenas_csi.metadata[0].name
  }

  type = "Opaque"

  data_wo = {
    "api-key" = var.truenas_api_key
  }

  data_wo_revision = 1
}

resource "helm_release" "truenas_csi" {
  name = "truenas-csi"

  repository = "https://raw.githubusercontent.com/truenas/truenas-csi/master/charts"
  chart      = "truenas-csi"
  version    = var.chart_version

  namespace = kubernetes_namespace_v1.truenas_csi.metadata[0].name

  create_namespace = false

  wait    = true
  atomic  = true
  timeout = 600

  postrender = {
    binary_path = "${path.module}/postrender-truenas-csi.sh"
  }

  values = [
    yamlencode({
      truenas = {
        url = "wss://${var.truenas_host}"

        defaultPool = var.truenas_pool

        nfsServer = var.truenas_host

        # TrueNAS uses a self-signed certificate by default.
        # We can replace this with proper CA validation later.
        insecureSkipTLS = true

        existingSecret = kubernetes_secret_v1.truenas_api.metadata[0].name
        existingSecretKey = "api-key"
      }

      storageClasses = [
        {
          name = "truenas-nfs"

          isDefault = false

          reclaimPolicy = "Retain"

          allowVolumeExpansion = true

          volumeBindingMode = "Immediate"

          mountOptions = [
            "nfsvers=4.1"
          ]

          parameters = {
            protocol = "nfs"

            pool = var.truenas_pool

            datasetPath = "k8s/nfs"

            compression = "LZ4"

            sync = "STANDARD"

            "nfs.rootSquash" = "true"
          }
        }
      ]
    })
  ]

  depends_on = [
    kubernetes_namespace_v1.truenas_csi,
    kubernetes_secret_v1.truenas_api
  ]
}