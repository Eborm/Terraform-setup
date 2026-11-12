resource "kubernetes_secret_v1" "grafana_admin" {
  metadata {
    name      = "grafana-admin"
    namespace = var.namespace
  }

  type = "Opaque"

  data_wo = {
    "admin-user"     = "admin"
    "admin-password" = var.admin_password
  }

  data_wo_revision = parseint(
    substr(sha256(var.admin_password), 0, 8),
    16
  )
}

resource "helm_release" "grafana" {
  name       = "grafana"
  repository = "https://grafana-community.github.io/helm-charts"
  chart      = "grafana"
  version    = var.chart_version

  namespace        = var.namespace
  create_namespace = false

  wait    = true
  atomic  = true
  timeout = 600

  values = [
    yamlencode({
      admin = {
        existingSecret = kubernetes_secret_v1.grafana_admin.metadata[0].name
        userKey        = "admin-user"
        passwordKey    = "admin-password"
      }

      sidecar = {
        dashboards = {
          enabled         = true
          SCProvider      = true
          label           = "grafana_dashboard"
          labelValue      = "1"
          searchNamespace = var.namespace
          watchMethod     = "WATCH"
          resource        = "configmap"

          provider = {
            name                      = "terraform-dashboards"
            orgid                     = 1
            folder                    = "Kubernetes"
            type                      = "file"
            disableDelete             = false
            allowUiUpdates            = false
            foldersFromFilesStructure = false
          }
        }
      }

      replicas = 1


      deploymentStrategy = {
        type = "Recreate"
      }

      persistence = {
        enabled       = true
        type          = "pvc"
        existingClaim = kubernetes_persistent_volume_claim_v1.grafana_data.metadata[0].name
      }

      initChownData = {
        enabled = false
      }

      ingress = {
        enabled          = true
        ingressClassName = "traefik"

        annotations = {
          "traefik.ingress.kubernetes.io/router.entrypoints" = "websecure"
          "traefik.ingress.kubernetes.io/router.tls"         = "true"
        }

        hosts    = [var.hostname]
        path     = "/"
        pathType = "Prefix"
      }

      "grafana.ini" = {
        server = {
          domain   = var.hostname
          root_url = "https://${var.hostname}"
        }
      }

      datasources = {
        "datasources.yaml" = {
          apiVersion = 1

          datasources = [
            {
              name      = "Prometheus"
              type      = "prometheus"
              access    = "proxy"
              url       = "http://prometheus.monitoring.svc.cluster.local:9090"
              uid       = "PBFA97CFB590B2093"
              isDefault = true
              editable  = false
            },
              {
                name      = "Loki"
                type      = "loki"
                access    = "proxy"
                url       = "http://loki.monitoring.svc.cluster.local:3100"
                uid       = "loki"
                isDefault = false
                editable  = false
              }
          ]
        }
      }

      resources = {
        requests = {
          cpu    = "100m"
          memory = "256Mi"
        }

        limits = {
          memory = "512Mi"
        }
      }
    })
  ]

  depends_on = [
    kubernetes_secret_v1.grafana_admin
  ]
}

resource "kubernetes_persistent_volume_claim_v1" "grafana_data" {
  metadata {
    name      = "grafana-data"
    namespace = var.namespace
  }

  spec {
    access_modes = ["ReadWriteMany"]

    storage_class_name = var.storage_class_name

    resources {
      requests = {
        storage = var.storage_size
      }
    }
  }
}